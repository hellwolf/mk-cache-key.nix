{
  halfBoardModule = {
    outputs = [ "out" ];
    includedFiles = [
      ./src
      ".*\\.data$"
    ];
    ignoredFiles = [
      ".*\\.md$"
      ./src/to-ignore.sh
    ];
    dependencies = [
      ../simplest
    ];
  };
}

