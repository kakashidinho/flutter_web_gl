// Copyright (c) 2013, John Thomas McDole.
/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_web_gl/flutter_web_gl.dart';

// part 'cube.dart';
part 'gl_program.dart';
// part 'json_object.dart';
// All the lessons
part 'lesson1.dart';
// part 'lesson10.dart';
// part 'lesson11.dart';
// part 'lesson12.dart';
// part 'lesson13.dart';
// part 'lesson14.dart';
// part 'lesson15.dart';
// part 'lesson16.dart';
// part 'lesson2.dart';
// part 'lesson3.dart';
// part 'lesson4.dart';
// part 'lesson5.dart';
// part 'lesson6.dart';
// part 'lesson7.dart';
// part 'lesson8.dart';
// part 'lesson9.dart';
// // Math
part 'matrix4.dart';
// part 'pyramid.dart';
// part 'rectangle.dart';
// // Some of our objects that we're going to support
// part 'renderable.dart';
// part 'sphere.dart';
// part 'star.dart';

late RenderingContext gl;
Lesson? lesson;

void startLesson([int lesson = 1]) {
  mvMatrix = new Matrix4()..identity();
  // Nab the context we'll be drawing to.
  gl = FlutterWebGL.getWebGLContext();

  // Set the fill color to black
  gl.clearColor(0, 0, 0, 1.0);

  // Start off the infinite animation loop
  tick(0);
}

/// This is the infinite animation loop; we request that the web browser
/// call us back every time its ready for a new frame to be rendered. The [time]
/// parameter is an increasing value based on when the animation loop started.
tick(time) {
  lesson.handleKeys();
  lesson.animate(time);
  lesson.drawScene(canvas.width, canvas.height, canvas.width / canvas.height);
}

/// The global key-state map.
Set<int> currentlyPressedKeys = new Set<int>();

/// Test if the given [KeyCode] is active.
bool isActive(int code) => currentlyPressedKeys.contains(code);

/// Test if any of the given [KeyCode]s are active, returning true.
bool anyActive(List<int> codes) {
  return codes.firstWhere((code) => currentlyPressedKeys.contains(code), orElse: () => null) != null;
}

/// Perspective matrix
late Matrix4 pMatrix;

/// Model-View matrix.
late Matrix4 mvMatrix;

List<Matrix4> mvStack = <Matrix4>[];

/// Add a copy of the current Model-View matrix to the the stack for future
/// restoration.
mvPushMatrix() => mvStack.add(new Matrix4.fromMatrix(mvMatrix));

/// Pop the last matrix off the stack and set the Model View matrix.
mvPopMatrix() => mvMatrix = mvStack.removeLast();

// /// Handle common keys through callbacks, making lessons a little easier to code
// void handleDirection({up(), down(), left(), right()}) {
//   if (left != null && anyActive([KeyCode.A, KeyCode.LEFT])) {
//     left();
//   }
//   if (right != null && anyActive([KeyCode.D, KeyCode.RIGHT])) {
//     right();
//   }
//   if (down != null && anyActive([KeyCode.S, KeyCode.DOWN])) {
//     down();
//   }
//   if (up != null && anyActive([KeyCode.W, KeyCode.UP])) {
//     up();
//   }
// }

/// The base for all Learn WebGL lessons.
abstract class Lesson {
  /// Render the scene to the [viewWidth], [viewHeight], and [aspect] ratio.
  void drawScene(num viewWidth, num viewHeight, num aspect);

  /// Animate the scene any way you like. [now] is provided as a clock reference
  /// since the scene rendering started.
  void animate(num now) {}

  /// Handle any keyboard events.
  void handleKeys() {}

  /// Added for your convenience to track time between [animate] callbacks.
  num lastTime = 0;
}

/// Load the given image at [url] and call [handle] to execute some GL code.
/// Return a [Future] to asynchronously notify when the texture is complete.
Future<Texture> loadTexture(String url, handle(Texture tex, ImageElement ele)) {
  var completer = new Completer<Texture>();
  var texture = gl.createTexture();
  var element = new ImageElement();
  element.onLoad.listen((e) {
    handle(texture, element);
    completer.complete(texture);
  });
  element.src = url;
  return completer.future;
}

/// This is a common handler for [loadTexture]. It will be explained in future
/// lessons that require textures.
void handleMipMapTexture(Texture texture, ImageElement image) {
  gl.pixelStorei(WebGL.UNPACK_FLIP_Y_WEBGL, 1);
  gl.bindTexture(WebGL.TEXTURE_2D, texture);
  gl.texImage2D(
    WebGL.TEXTURE_2D,
    0,
    WebGL.RGBA,
    WebGL.RGBA,
    WebGL.UNSIGNED_BYTE,
    image,
  );
  gl.texParameteri(
    WebGL.TEXTURE_2D,
    WebGL.TEXTURE_MAG_FILTER,
    WebGL.LINEAR,
  );
  gl.texParameteri(
    WebGL.TEXTURE_2D,
    WebGL.TEXTURE_MIN_FILTER,
    WebGL.LINEAR_MIPMAP_NEAREST,
  );
  gl.generateMipmap(WebGL.TEXTURE_2D);
  gl.bindTexture(WebGL.TEXTURE_2D, null);
}

DivElement lessonHook = querySelector("#lesson_html");
bool trackFrameRate = false;

Lesson selectLesson(int number) {
  switch (number) {
    case 1:
      return new Lesson1();
    case 2:
      return new Lesson2();
    case 3:
      return new Lesson3();
    case 4:
      return new Lesson4();
    case 5:
      return new Lesson5();
    case 6:
      return new Lesson6();
    case 7:
      return new Lesson7();
    case 8:
      return new Lesson8();
    case 9:
      return new Lesson9();
    case 10:
      return new Lesson10();
    case 11:
      return new Lesson11();
    case 12:
      return new Lesson12();
    case 13:
      return new Lesson13();
    case 14:
      return new Lesson14();
    case 15:
      return new Lesson15();
    case 16:
      return new Lesson16();
  }
  return null;
}

/// Work around for setInnerHtml()
class NullTreeSanitizer implements NodeTreeSanitizer {
  static NullTreeSanitizer instance;
  factory NullTreeSanitizer() {
    if (instance == null) {
      instance = new NullTreeSanitizer._();
    }
    return instance;
  }

  NullTreeSanitizer._();
  void sanitizeTree(Node node) {}
}
