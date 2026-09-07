library;

import 'package:flutter/material.dart';

class HomepageTv extends StatelessWidget {
  const HomepageTv({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Accueil TV',
          style: TextStyle(color: Colors.white, fontSize: 32),
        ),
      ),
    );
  }
}
