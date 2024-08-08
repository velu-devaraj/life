import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:logger/logger.dart';

typedef NewCells<T> = void Function(T value);

class Life {
  int m = 5;
  int n = 5;
  int generationTimeSec = 5;
  final log = Logger();
  List<List<bool>> cells = List.empty(growable: true);
  NewCells<List<List<bool>>> newCellsGenerated;

  factory Life.withRecord(Record rec) {
    if (rec is (List<List<bool>>, int, NewCells<List<List<bool>>>)) {
      return Life.withProvidedCells(rec.$1, rec.$2, rec.$3);
    } else if (rec is (int, int, int, NewCells<List<List<bool>>>)) {
      return Life.withRandomCells(rec.$1, rec.$2, rec.$3, rec.$4);
    }
    throw Exception("Invalid Record in Life Constructor");
  }

  factory Life.withList(List list) {
    if (list.length == 3 && list[0] is List<List<bool>> && list[1] is int && list[2] is NewCells<List<List<bool>>>) {
      return Life.withRecord( (list[0], list[1], list[2]));
    } else if (list.length == 4 && list[0] is int && list[1] is int && list[2] is int  && list[3] is NewCells<List<List<bool>>>){
       return Life.withRecord( (list[0], list[1], list[2], list[3]));
    }
    throw Exception("Invalid Record in Life Constructor");
  }

  Life.withProvidedCells(
      this.cells, this.generationTimeSec, this.newCellsGenerated) {
    m = cells.length;
    n = cells[0].length;
  }

  Life.withRandomCells(
      this.m, this.n, this.generationTimeSec, this.newCellsGenerated) {
    initWithRandom();
  }

  Life.asEmpty(this.m, this.n, this.generationTimeSec, this.newCellsGenerated) {
    initAsLifeless();
  }

  void initWithRandom() {
    for (int i = 0; i < m; i++) {
      cells.add(List.empty(growable: true));
      for (int j = 0; j < n; j++) {
        cells[i].add(Random().nextBool());
      }
    }
  }

  List<List<bool>> initAsLifeless() {
    List<List<bool>> newCells = List.empty(growable: true);
    for (int i = 0; i < m; i++) {
      newCells.add(List.empty(growable: true));
      for (int j = 0; j < n; j++) {
        newCells[i].add(false);
      }
    }
    return newCells;
  }

  bool nextGeneration() {
    var newCells = initAsLifeless();
    log.i("creating new generation:");

    bool isExtinct = false;
    bool isModified = false;
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        newCells[i][j] = willBeLiveCell(i, j);
        if (newCells[i][j] != cells[i][j]) {
          isModified = true;
        }
        isExtinct = isExtinct ? newCells[i][j] : isExtinct;
      }
    }
    log.i("New generation is modified : $isModified");
    log.i("New generation is dead: $isExtinct");
    cells = newCells;

    return isExtinct;
  }

  bool isLiveCell(int i, int j) {
    return i < 0 || i >= m || j < 0 || j >= n ? false : cells[i][j];
  }

  int countNeighbors(int i, int j) {
    int count = 0;
    if (isLiveCell(i - 1, j - 1)) count++;
    if (isLiveCell(i - 1, j)) count++;
    if (isLiveCell(i - 1, j + 1)) count++;
    if (isLiveCell(i, j - 1)) count++;
    if (isLiveCell(i, j + 1)) count++;
    if (isLiveCell(i + 1, j - 1)) count++;
    if (isLiveCell(i + 1, j)) count++;
    if (isLiveCell(i + 1, j + 1)) count++;

    return count;
  }

  bool willBeLiveCell(int i, int j) {
    int count = countNeighbors(i, j);

    if (cells[i][j] && count < 2) return false;
    if (cells[i][j] && (count == 2 || count == 3)) return true;
    if (cells[i][j] && count > 3) return false;
    if (!cells[i][j] && count == 3) return true;
    return false;
  }

  void delay() {
    sleep(Duration(milliseconds: generationTimeSec));
  }

  Timer? lTimer;
  Timer? startTimer() {
    int count = 0;
    lTimer = Timer.periodic(Duration(milliseconds: generationTimeSec), (timer) {
      nextGeneration();
      newCellsGenerated(cells);

      if (count++ > 1000) {
        timer.cancel();
      }
    });

    return lTimer;
  }

  void stop() {
    if (null == lTimer) {
      return;
    }
    lTimer!.cancel();
    lTimer = null;
  }
}
