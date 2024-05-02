import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tab Controller App',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Widget customTab(String imagePath) {
    return Tab(
      height: 75,
      // iconMargin: EdgeInsets.all(5.0),
      child: Image.asset(
        imagePath,
        // width: 100, // Adjust width as needed
        // height: 100, // Adjust height as needed
        fit: BoxFit
            .contain, // Optional: adjust how the image should be inscribed into the space
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Center(
                  child: Text('Content of Tab 1'),
                ),
                Center(
                  child: Text('Content of Tab 2'),
                ),
              ],
            ),
          ),
          Container(
            height: 85, // Adjust the height as needed
            color: Theme.of(context).primaryColor,
            // padding: EdgeInsets.all(0.0),
            margin: null,
            child: TabBar(
              controller: _tabController,
              tabs: [
                customTab('assets/images/icons-group1.png'),
                customTab('assets/images/energies2.png'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
