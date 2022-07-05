//global variables
var GREETING = "Hello";

//function
fun add(a, b) {
    return a + b;
}

//class
class Point {
    //initializer
    init(x, y) {
        this.x = x;
        this.y = y;
    }

    //method
    move(x, y) {
        this.x = this.x + x;
        this.y = this.y + y;
    }

    //static method
    static square(x) {
        return x * x;
    }
}

//function call
add(1, 2);
var sum = add(4, 2);

//print statement
print sum;


//class call
var p = Point(1, 2);

//when init is not defined a default initializer is provided
class Foo{}
var bar = Foo();

//attributes can be added after class is constructed
bar.z = 3;
print bar.z;


