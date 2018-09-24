import 
  unittest, jsffi, jsconsole, json,
  nes

proc toJson*[T](data: T): cstring {.importc: "JSON.stringify".}
proc fromJson*[T](blob: cstring): T {.importc: "JSON.parse".}

## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes#Class_declarations
suite "ES2015 Classes":
  test "class declarations":
    class Rectangle:
      height: int
      width: int
      constructor:
        this.height = height
        this.width = width

    let
      expected = ES2015Class{height: 5, width: 5}
      actual = newRectangle(5, 5)
    
    require(toJson(expected) == toJson(actual))
  
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes#Prototype_methods
  test "getters":
    # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/get
    class Rectangle:
      height: int
      width: int
      constructor:
        this.height = height
        this.width = width
      proc getArea(): int =
        return this.height * this.width

    let
      expected = 25
      actual = newRectangle(5, 5).getArea()
    
    require(expected == actual)
  
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes#Prototype_methods
  test "setters":
    # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/set
    class Rectangle:
      height: int
      width: int
      constructor:
        this.height = height
        this.width = width
      proc getArea(): int =
        return this.height * this.width
      proc setScale(s: float) =
        this.width = this.width * s
        this.height = this.height * s
    
    let
      r = newRectangle(1, 1)
      expected = 25
    
    r.setScale(5.0)

    require(expected == r.getArea())
  
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes#Prototype_methods
  test "methods":
    # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Method_definitions
    class Rectangle:
      height: int
      width: int
      constructor:
        this.height = height
        this.width = width
      proc getArea(): int =
        return this.calcArea()
      proc calcArea(): int =
        return this.width * this.height
    
    let
      r = newRectangle(5,5)
      expected = 25
      actual = r.getArea()

    require(expected == actual)
  
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes#Prototype_methods#Static_methods
  test "static methods":
    class Point:
      x: int
      y: int
      constructor:
        this.x = x
        this.y = y
      proc staticDistance(a, b: Point): float =
        const dx = a.x - b.x
        const dy = a.y - b.y

        return Math.hypot(dx, dy)
    
    let
      expected = 7.0710678118654755
      p1 = newPoint(5, 5)
      p2 = newPoint(10, 10)
      actual = distance(p1, p2)

    require(expected == actual)