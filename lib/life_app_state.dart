class LifeAppState {
  bool appStarted = false;
  bool rowSet = false;
  bool columnSet = false;
  bool cellsSet = false;
  bool isRunning = false;
  bool isStopped = false;
  bool genTimeSet = false;

  bool canStart() {
    if (rowSet && columnSet && genTimeSet) {
      if (isRunning) {
        return false;
      } else {
        return true;
      }
    } else {
      return false;
    }
  }

  bool canSetCellValue() {
    if (rowSet && columnSet) {
      if (isRunning) {
        return false;
      } else {
        return true;
      }
    } else {
      return false;
    }
  }
}
