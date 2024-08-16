import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:life/bridge.dart';
import 'package:life/life.dart';
import 'package:life/life_app_state.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_spinbox/material.dart';

const Color darkBlue = Color.fromARGB(255, 18, 32, 47);

void main() {
  final log = Logger();
  runApp(new MyApp());
  log.i("main() finished");
}

class MyApp extends StatelessWidget {
  final log = Logger();
  final Key lifeAppWidgetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Life",
      home: LifeAppWidget(key: lifeAppWidgetKey),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ignore: must_be_immutable
class LifeAppWidget extends StatelessWidget {
  static final log = Logger();
  LifeGridPainter? lifeGridPainter;
  GestureDetector? gestureDetector;
  GridWidgetState? gridWidgetState;
  List<List<bool>>? canvasCells;

  final GlobalKey lifeAppWidgetKey = GlobalKey();
  final GlobalKey gestureDetectorKey = GlobalKey();
  final GlobalKey rowSpinnerKey = GlobalKey();

  TextStyle buttonTextStyle = const TextStyle(
    color: Colors.lightBlueAccent,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  LifeAppWidget({required Key key}) : super(key: key) {
    lifeGridPainter = LifeGridPainter();
    gestureDetector = GestureDetector(
        key: gestureDetectorKey,
        onDoubleTapDown: (details) {
          log.i(details.localPosition);

          if (null == rowCount || null == columnCount) {
            return;
          } else {
            canvasCells ??= initAsLifeless();
          }

          gridWidgetState!.update(canvasCells!);
          log.i(gestureDetectorKey.currentContext!.size);

          // gestureDetector.child.
          int col = details.localPosition.dx.round();
          int row = details.localPosition.dy.round();

          var rec = localPositionToCellID(
              details.localPosition, gestureDetectorKey.currentContext!.size);

          if (gridWidgetState!.updateCell(rec.$1, rec.$2)) {
            laState.cellsSet = true;
          }
        },
        child: CustomPaint(painter: lifeGridPainter));
    gridWidgetState = GridWidgetState(lifeGridPainter!, gestureDetector!);
    gw = GridWidget(
        key: UniqueKey(),
        gridWidgetState: gridWidgetState,
        gestureDetector: gestureDetector!);
  }

  (int, int) localPositionToCellID(Offset offset, Size? canvasSize) {
    double renderedXSize = 25.0 * columnCount!;
    double renderedYSize = 25.0 * rowCount!;
    double xStart = (canvasSize!.width - renderedXSize) / 2;
    double yStart = (canvasSize.height - renderedYSize) / 2;
    int col = ((offset.dy - yStart) / 25).floor();
    int row = ((offset.dx - xStart) / 25).floor();

    return (row, col);
  }

  List<List<bool>> initAsLifeless() {
    List<List<bool>> newCells = List.empty(growable: true);
    for (int i = 0; i < columnCount!; i++) {
      newCells.add(List.empty(growable: true));
      for (int j = 0; j < rowCount!; j++) {
        newCells[i].add(false);
      }
    }
    return newCells;
  }

  Bridge<Life>? lifeInterface;

  CustomPaint? cp;
  GridWidget? gw;
  int messageCount = 0;
  bool isRunning = false;

  int? rowCount = 7;
  int? columnCount = 7;

  int? generateMilliSec = 500;

  LifeAppState laState = LifeAppState();
  ReceivePort lifeReceivePort = ReceivePort();
  late SendPort lifeSendPort;
  late GestureDetector gd;

  bool? withRandomCells;

  void newCellsgenerated(List<List<bool>> cells) {
    gw!.gridWidgetState!.update(cells);
  }

  double? screenWidth;
  double? screenHeight;

  Widget buildMaterialApp(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: darkBlue),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          appBar: AppBar(
              title: FittedBox(
                child: Text("Life"),
                fit: BoxFit.contain,
              ),
              actions: null),
          body: Column(
            children: <Widget>[
              Expanded(
                  child: LayoutBuilder(
                builder: (_, constraints) => Container(
                    width: constraints.widthConstraints().maxWidth,
                    height: constraints.heightConstraints().maxHeight,
                    //                     color: Colors.black38,
                    child: gw),
              )),
              SizedBox(
                  height: 240,
                  //  width: 600 ,
                  child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: false,
                      primary: true,
                      childAspectRatio: 5,
                      padding: const EdgeInsets.all(5),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      crossAxisCount: 3,
                      children: <Widget>[
                        SpinBox(
                          key: rowSpinnerKey,
                          textStyle: const TextStyle(color: Colors.blueAccent),
                          showButtons: true,
                          min: 5,
                          max: (screenHeight! - 300) / 25,
                          value: rowCount!.toDouble(),
                          decoration: InputDecoration(
                              labelText: 'Rows'),
                          onChanged: (value) {
                            if (laState.appStarted) {
                              return;
                            }
                            rowCount = value.toInt();
                            gridWidgetState!
                                .updateBorder(rowCount!, columnCount!);
                          },
                        ),
                        SpinBox(
                          textStyle: const TextStyle(color: Colors.blueAccent),
                          showButtons: true,
                          min: 5,
                          max: (screenWidth! - 50) / 25,
                          value: columnCount!.toDouble(),
                          decoration: InputDecoration(
                              labelText: 'Columns'),
                          onChanged: (value) {
                            if (laState.appStarted) {
                              return;
                            }
                            columnCount = value.toInt();
                            gridWidgetState!
                                .updateBorder(rowCount!, columnCount!);
                          },
                        ),
                        SpinBox(
                          textStyle: const TextStyle(color: Colors.blueAccent),
                          showButtons: true,
                          min: 100,
                          max: 5000,
                          value: 500,
                          decoration: InputDecoration(
                              labelText: 'Generate Milli Sec'),
                          onChanged: (value) {
                            if (laState.appStarted) {
                              return;
                            }
                            generateMilliSec = value.toInt();
                          },
                        ),
                        SizedBox(
                            width: 75,
                            height: 50,
                            child: ElevatedButton(
                              style: style,
                              onPressed: () {
                                if (!laState.appStarted) {
                                  laState.isRunning = true;
                                  laState.cellsSet = true;
                                  withRandomCells = true;
                                  lifeInterface = Bridge.fromList(
                                      Life.withList,
                                      [columnCount, rowCount, generateMilliSec],
                                      newCellsgenerated,
                                      kIsWeb ? false : true);
                                  lifeInterface!
                                      .callDelegateFromList(["start"]);
                                  laState.appStarted = true;
                                }
                              },
                              child:
                                  Text('Start Random', style: buttonTextStyle),
                            )),
                        SizedBox(
                            width: 75,
                            height: 50,
                            child: ElevatedButton(
                              style: style,
                              onPressed: () => showWithSelectedCells(context),
                              child: Text('Start', style: buttonTextStyle),
                            )),
                        SizedBox(
                            width: 75,
                            height: 50,
                            child: ElevatedButton(
                              style: style,
                              onPressed: () {
                                if (laState.isRunning) {
                                  laState.isRunning = false;
                                  lifeInterface!.callDelegateFromList(["stop"]);
                                }
                              },
                              child: Text('Stop', style: buttonTextStyle),
                            )),
                      ]))
            ],
          )),
    );
  }

  final ButtonStyle style = ElevatedButton.styleFrom(
      textStyle: const TextStyle(fontSize: 10),
      shape: const LinearBorder(
        side: BorderSide(color: Colors.blue),
        bottom: LinearBorderEdge(),
      ),
      fixedSize: const Size(60, 25));

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    gd = GestureDetector(
        onDoubleTapDown: (details) {
          log.d(details.localPosition);
        },
        child: CustomPaint(painter: lifeGridPainter));

    Widget w = buildMaterialApp(context);
    this.gridWidgetState!.updateBorder(rowCount!, columnCount!);
    return w;
  }

  void showWithSelectedCells(BuildContext context) {
    if (laState.canStart()) {
      if (null == lifeInterface) {
        withRandomCells = false;
        lifeInterface = Bridge.fromList(
            Life.withList,
            [lifeGridPainter!.receivedCells, generateMilliSec],
            newCellsgenerated,
            kIsWeb ? false : true);
        lifeInterface!.callDelegateFromList(["start"]);
        laState.isRunning = true;
        laState.appStarted = true;
      } else {
        lifeInterface!.callDelegateFromList(["start"]);
        laState.isRunning = true;
      }
    } else if (laState.isRunning) {
      return;
    } else {
      _dialogBuilder(context);
    }
  }

  Future<void> _dialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No living cells'),
          content: const Text(
            'Please double tap in canvas area to toggle cells.',
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class GridWidget extends StatefulWidget {
  GridWidget(
      {required Key key,
      required this.gridWidgetState,
      required this.gestureDetector})
      : super(key: key);

  GridWidgetState? gridWidgetState;
  GestureDetector gestureDetector;
  final log = Logger();

  @override
  // ignore: no_logic_in_create_state
  State<StatefulWidget> createState() {
    log.i("createState called");
    return gridWidgetState!;
  }
}

class GridWidgetState extends State<StatefulWidget> {
  final log = Logger();
  LifeGridPainter lifeGridPainter;
  GestureDetector gd;

  GridWidgetState(this.lifeGridPainter, this.gd);

  void update(List<List<bool>> newCells) {
    lifeGridPainter.receivedCells = newCells;

    log.i("update called");
    lifeGridPainter.notifyListeners();
  }

  void updateBorder(int row, int col) {
    log.i("updateBorder called");
    lifeGridPainter.currentRows = row;
    lifeGridPainter.currentColumns = col;
    lifeGridPainter.notifyListeners();
  }

  bool updateCell(int i, int j) {
    log.d("updateCell called");
    if (i < 0 || i >= lifeGridPainter.receivedCells!.length) {
      return false;
    }
    if (j < 0 || j >= lifeGridPainter.receivedCells![0].length) {
      return false;
    }
    lifeGridPainter.receivedCells![i][j] =
        !lifeGridPainter.receivedCells![i][j];

    log.d("updateCell called");
    lifeGridPainter.notifyListeners();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return gd;
  }
}

class LifeGridPainter extends ChangeNotifier implements CustomPainter {
  final log = Logger();
  LifeGridPainter() {
    receivedCells = List.empty(growable: true);
  }

  int? _currentRows;

  int? get currentRows => _currentRows;

  set currentRows(int? value) {
    _currentRows = value;
  }

  int? _currentColumns;

  int? get currentColumns => _currentColumns;

  set currentColumns(int? value) {
    _currentColumns = value;
  }

  late List<List<bool>>? receivedCells;

  @override
  void paint(Canvas canvas, Size size) {
    log.d("Calling paint ");
    // Define a paint object
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4.0
      ..color = Colors.greenAccent;

    final paintDead = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4.0
      ..color = Color.fromRGBO(8, 18, 8, 4);

    const double rSize = 25.0;

    if (receivedCells == null || receivedCells!.isEmpty) {
      if (null == currentRows || null == currentColumns) {
        return;
      }
      double xStart = (size.width - rSize * currentColumns!) / 2;
      double yStart = (size.height - rSize * currentRows!) / 2;

      canvas.drawRect(
        Rect.fromLTWH(xStart, yStart, rSize * currentColumns!.toDouble(),
            rSize * currentRows!.toDouble()),
        paintDead,
      );
      return;
    }

    int m = receivedCells!.length;
    int n = receivedCells![0].length;

    double xStart = (size.width - rSize * m) / 2;
    double yStart = (size.height - rSize * n) / 2;

    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  xStart + (rSize * i), yStart + (rSize * j), rSize, rSize),
              const Radius.circular(3)),
          getCellValue(receivedCells, i, j) ? paint : paintDead,
        );
      }
    }
  }

  bool getCellValue(List<List<bool>>? inCells, int i, int j) {
    if (inCells == null) {
      log.d("null cells");
      return false;
    }
    return inCells[i][j];
  }

  @override
  bool shouldRepaint(LifeGridPainter oldDelegate) => true;

  @override
  bool get hasListeners => true;

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  @override
  bool? hitTest(Offset position) => true;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) {
    return true;
  }
}
