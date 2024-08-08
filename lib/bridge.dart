import 'dart:async';
import 'dart:core';
import 'dart:isolate';
import 'package:logger/logger.dart';
import 'package:life/life.dart';

class Backport {
  SendPort backport;
  Backport(this.backport);
  void returnData(List<List<bool>> x) {
    backport.send(x);
  }
}

class Bridge<T> {
  final log = Logger();
  T? t;
  (
    Future<Isolate>? isolateFuture,
    ReceivePort receivePort,
    SendPort sendPort
  )? localData;
  NewCells<List<List<bool>>> newCellsGenerated;

  NewCells<List<List<bool>>>? newCellsGeneratedLocal;

  bool inIsolate;

  Bridge.fromList(T Function(List constructorArgs) constructorFunction,
      List constructorArgs, this.newCellsGenerated, this.inIsolate) {
    if (inIsolate) {
      ReceivePort rp = ReceivePort();

      Future<Isolate>? ifuture;

      StreamSubscription<dynamic> streamSubscription = rp.listen((message) {
        if (null == localData && message is SendPort) {
          SendPort sp = message;
          localData = (ifuture, rp, sp);
          _completer.complete(localData);

          callDelegateFromList(constructorArgs);
        } else {
          List<List<bool>> newCells = message;
          newCellsGenerated(newCells);
        }
      });

      ifuture = Isolate.spawn(entryPoint, rp.sendPort);
    } else {
      constructorArgs.add(this.newCellsGenerated);
      t = constructorFunction(constructorArgs);
    }
  }

  static void entryPoint(SendPort port) {
    ReceivePort rp = ReceivePort();
    Life? life;

    Backport? backPort = Backport(port);
    rp.listen((message) {
      if (message is List) {
        List list = message;
        String commandName;

        if (list.length == 3) {
          life =
              Life.withList([list[0], list[1], list[2], backPort.returnData]);
        }
        if (list.length == 2) {
          life = Life.withList([list[0], list[1], backPort.returnData]);
        }
        if (list.length == 1) {
          commandName = list[0];
          if ("start" == commandName) {
            life!.startTimer();
          } else if ("stop" == commandName) {
            life!.stop();
          }
        }

        return;
      }
    });

    port.send(rp.sendPort);
  }

  final Completer _completer = Completer();

  Future<dynamic> sendBack() {
    return _completer.future;
  }

  void callDelegateFromList(List list) {
    String commandName;

    if (null != localData) {
      localData!.$3.send(list);
      return;
    } else if (inIsolate) {
      // not ready yet
      log.d("localdata sendport not initialized yet");
      sendBack().then((onValue) {
        log.d("localdata sendport initialized now");
        onValue.$3.send(list);
      });

      return;
    }
    if (list.length == 3) {
      if (!inIsolate) {
        t = Life.withRandomCells(list[0], list[1], list[2], list[3]) as T?;
      }
    }
    if (list.length == 2) {
      commandName = list[3];
      if (!inIsolate) {
        t = Life.withProvidedCells(list[0], list[1], list[2]) as T?;
      }
    }
    if (list.length == 1) {
      if (null == t) {
        log.d("life not initialized");
        return;
      }
      commandName = list[0];
      Life l = t as Life;
      if ("start" == commandName) {
        l.startTimer();
      } else if ("stop" == commandName) {
        l.stop();
      }
    }
  }
}
