{
  halfBoardModule = {
    dependencies = [
      ../simplest
      # cyclical
      ../cyclical
      # self-cyclical
      ./.
    ];
  };
}
