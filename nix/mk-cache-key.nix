# * Synopsis: Nix expression of creating cache key for "half board" nix projects.

# * Background
#   Refer to README.md for the backround.
#
# * How to use:
#
#   Use nix eval to get a json output of cache description of a "half board" module:
#   ```shell
#   $ nix eval --file nix/mk-cache-key.nix \
#       --show-trace \
#       --apply "f: f {
#                  nixpkgs = import <nixpkgs> {};
#                  gitdir = ./.;
#                  modulePath = ./packages/a-half-board-module;
#                  additionalContextFile = ./additional-build-context.ignored;
#             }" \
#       --json | jq keys
#   [
#     "additionalContext",
#     "closure",
#     "files",
#     "hash",
#     "outputs"
#   ]
#   ```
#
#   One may also use nix-instantiate to achieve the same result.
#
# * Half Board Module Definition
#   ```nix
#   { halfBoardModule = {
#       dependencies = [
#         ../..
#       ]; # default: [ ]
#       outputs = [
#       ]; # default: [ ]
#       includedFiles = [
#       ]; # default, including all git-tracked files: [ ".*" ]
#       ignoredFiles = [
#       ]; # default: [ ]
#   };
#   }
{
  nixpkgs,
  # Absolute path to the root of the git project.
  gitdir,
  # Absolute path to the module where the half board module is defined as `(import m).halfBoardModule`.
  modulePath,
  # A file that provides additional context that may affect the build output, such as the status of
  # git submodules.
  additionalContextFile ? null,
}:
with nixpkgs;
let
  # Constants
  #
  HASH_ALGO = "sha256";
  gitTrackedFiles = lib.fileset.gitTracked gitdir;
  # remove gitdir from path
  # :: Path -> String
  toGitPath = lib.path.removePrefix gitdir;
  # append gitdir to a string
  # :: String -> Path
  fromGitPath = lib.path.append gitdir;
  # Filter git tracked files using included files and ignored files.
  # :: Path -> [ Path | String ] -> FileSet
  filterGitTrackedFiles =
    src: filters:
    let
      pathFilters = map (f: fromGitPath f.value) (lib.filter (f: f.type == "path") filters);
      regexFilters = map (f: f.value) (lib.filter (f: f.type == "regex") filters);
    in
    lib.fileset.intersection gitTrackedFiles (
      lib.fileset.union
        # Create a list of file sets for path-typed filters
        (lib.fileset.unions pathFilters)
        # Create a list of file sets from regex-typed filters
        (
          lib.fileset.fromSource (
            lib.sources.cleanSourceWith {
              inherit src;
              filter =
                path: type:
                # always included directory in the set for further filtering,
                if type == "directory" then
                  true
                # otherwise, if any regex filter matches, include the file.
                else
                  lib.any (r: !isNull (builtins.match r path)) regexFilters;
            }
          )
        )
    );
  # List files (as strings) of a half-board module
  # :: HalfBoardModule -> [ String ]
  filesInModule =
    {
      modulePath,
      includedFiles,
      ignoredFiles,
      ...
    }:
    let
      src = fromGitPath modulePath;
      posSets = filterGitTrackedFiles src includedFiles;
      negSets = filterGitTrackedFiles src ignoredFiles;
    in
    # lib.trace (lib.fileset.trace posSets) (
    #   lib.trace (lib.fileset.trace negSets) (
    lib.sort (p: q: p < q) (map toString (lib.fileset.toList (lib.fileset.difference posSets negSets)));
  #   )
  # );

  # Make a hash from a list of files
  # :: [ String ] -> String
  hashFileOrSymlink =
    file:
    let
      type = lib.pathType (/. + file);
    in
    if type == "symlink" then
      # nix doesn't seem to have builtin readlink, using
      builtins.hashString HASH_ALGO (lib.sources.cleanSource file).outPath
    else if type == "regular" then
      builtins.hashFile HASH_ALGO file
    else
      throw throw "Unhashable file type ${type}";
  hashFiles =
    files: builtins.hashString HASH_ALGO (lib.strings.concatStrings (map hashFileOrSymlink files));
  # Import a half-board module
  # :: Path -> HalfBoardModule
  importHB =
    m:
    let
      # toGitPath if it is a path, otherwise return as it is
      # :: [string | Path] -> String
      toFilePattern =
        a:
        if builtins.typeOf a == "path" then
          {
            type = "path";
            value = toGitPath a;
          }
        else
          {
            type = "regex";
            value = a;
          };
      modulePath = toGitPath m;
      # sanitize inputs and provide a attribute set with default values
      sanitize =
        {
          dependencies ? [ ],
          includedFiles ? [ ".*" ],
          ignoredFiles ? [ ],
          outputs ? [ ],
        }@s:
        {
          # convert dependencies to relative paths to gitdir
          dependencies = map toGitPath dependencies;
          includedFiles = map toFilePattern includedFiles;
          ignoredFiles = map toFilePattern ignoredFiles;
          outputs = map (o: toGitPath (lib.path.append m o)) outputs;
        };
    in
    sanitize (import m).halfBoardModule // { inherit modulePath; };
  # Intermediate Results
  #
  closure =
    let
      go =
        clo:
        let
          clo' = lib.lists.unique (
            clo ++ (lib.lists.flatten (map (m: (map fromGitPath (importHB m).dependencies)) clo))
          );
        in
        if lib.length clo == lib.length clo' then clo else go clo';
    in
    map importHB (lib.sort (p: q: p < q) (go [ modulePath ]));
  files = lib.lists.flatten (map filesInModule closure);
  outputs = lib.lists.flatten (map (m: m.outputs) closure);
in
{
  inherit closure outputs;
  files = map toGitPath (map (m: /. + m) files);
  additionalContext = if isNull additionalContextFile then "" else lib.readFile additionalContextFile;
  hash = hashFiles (
    files ++ (if isNull additionalContextFile then [ ] else [ additionalContextFile ])
  );
}
