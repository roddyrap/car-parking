import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cars_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();

  void tryLogin() async {
    print("Loggin in with: ${loginEmailController.text}");
    try {
      FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmailController.text,
        password: loginPasswordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      }
    } catch (e) {
      print(e);
    }

    if (FirebaseAuth.instance.currentUser != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CarsPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the LoginPage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Container(
        // padding: EdgeInsets.all(20),
        child: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(
            // Column is also a layout widget. It takes a list of children and
            // arranges them vertically. By default, it sizes itself to fit its
            // children horizontally, and tries to be as tall as its parent.
            //
            // Column has various properties to control how it sizes itself and
            // how it positions its children. Here we use mainAxisAlignment to
            // center the children vertically; the main axis here is the vertical
            // axis because Columns are vertical (the cross axis would be
            // horizontal).
            //
            // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
            // action in the IDE, or press "p" in the console), to see the
            // wireframe for each widget.
            mainAxisAlignment: .center,
            spacing: 10,

            children: [
              SizedBox(width: 400, child: TextField(controller: loginEmailController, decoration: InputDecoration(border: OutlineInputBorder(), labelText: 'Email'))),
              SizedBox(width: 400, child: TextField(controller: loginPasswordController, obscureText: true, decoration: InputDecoration(border: OutlineInputBorder(), labelText: 'Password'))),
              Row(
                mainAxisAlignment: .center,
                spacing: 5,
                children: [
                  ElevatedButton(onPressed: tryLogin, child: Text("Login")),
                  ElevatedButton(onPressed: null, child: Text("Register")),
                ],
              )
            ],
          ),
        )
      ),
    );
  }
}
