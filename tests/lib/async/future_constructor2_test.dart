// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library future_delayed_test;

import 'package:async_helper/async_helper.dart';
import "package:expect/expect.dart";
import 'dart:async';

Future<int> voidToIntFuture() {
  return new Future<int>.value(499);
}

unnamed() {
  asyncStart();
  new Future<int>(voidToIntFuture)
      .then((x) {
    Expect.equals(499, x);
    asyncEnd();
  });
}

delayed() {
  asyncStart();
  new Future<int>.delayed(const Duration(milliseconds: 2), voidToIntFuture)
      .then((x) {
    Expect.equals(499, x);
    asyncEnd();
  });
}

microtask() {
  asyncStart();
  new Future<int>.microtask(voidToIntFuture)
      .then((x) {
    Expect.equals(499, x);
    asyncEnd();
  });
}

sync() {
  asyncStart();
  new Future<int>.sync(voidToIntFuture)
      .then((x) {
    Expect.equals(499, x);
    asyncEnd();
  });
}

main() {
  // Test that all the Future constructors take functions that return a Future
  // as argument.
  // In particular the constructors must not type their argument as
  // `T computation()`.
  unnamed();
  delayed();
  microtask();
  sync();
}
