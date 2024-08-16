class LifeAppState {
  bool appStarted = false;
  bool cellsSet = false;
  bool isRunning = false;
  bool isStopped = false;

  bool canStart() {
    if (cellsSet) {
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
    if (isRunning) {
      return false;
    } else {
      return true;
    }
  }
}
