import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/components/app_logo.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/config/theme_config.dart';

class Mapsmari extends StatefulWidget {
  const Mapsmari({super.key});

  @override
  State<Mapsmari> createState() => _MapsmariState();
}

class _MapsmariState extends State<Mapsmari> {
  @override
  void initState() {
    // Load Ads
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
  preferredSize: const Size.fromHeight(60), // ✅ fixed height
  child: AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    automaticallyImplyLeading: false,

    flexibleSpace: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? "assets/maris/Rectangle_red_dark.png"
              : "assets/maris/Rectangle_red.png",
          fit: BoxFit.fill, // ✅ IMPORTANT (not cover)
        ),
      ],
    ),

    leading: IconButton(
      onPressed: () => Navigator.pop(context),
      icon: Image.asset(
        "assets/maris/marispeakback.png",
        width: 30,
        height: 30,
      ),
    ),

    title: const Text(
      "About Marispeak",
      style: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w500,
        fontSize: 18,
      ),
    ),

    iconTheme: const IconThemeData(color: Colors.black),
  ),
),

      body: Column(
        children: [
SizedBox(
  width: double.infinity,
  height: 30, // height of the separator
  child: Stack(
    alignment: Alignment.centerLeft, // align text to left
    children: [
      Image.asset(
        "assets/maris/grey_seprator.png",
        width: double.infinity,
        height: 30,
        fit: BoxFit.cover, // fill width
      ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            " ",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 46, 46, 46),
            ),
          ),
        ),
    ],
  ),
),

          // Body content
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // ✅ IMPORTANT
              children: [
                
                const SizedBox(height: 10),

                // App name
                Text(
                  "About Marispeak Maps",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontSize: 22, fontWeight: FontWeight.normal, color: Colors.black),
                  textAlign: TextAlign.left,
                   ),

                const SizedBox(height: 10),
// App version
                Text(
                  "About our Maps",
                  style: TextStyle(
                    color: const Color.fromARGB(255, 0, 0, 0),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    
                  ),
                  textAlign: TextAlign.left,
                ),
                
                const SizedBox(height: 20),
                // App short description
                Text(
                  "Marispeak instantly turns your phone into a maritime communication and information tool. Access clear and secure voice communications, messaging, maps, water depths and weather, information, designed for the boating & Fishing communities",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(fontSize: 16,color: const Color.fromARGB(255, 28, 28, 28)),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
Expanded(
  child: Stack(
    alignment: Alignment.bottomLeft,
    children: [
      Image.asset(
        "assets/maris/grey_seprator.png",
        width: double.infinity,
        height: double.infinity, // fill parent Expanded
        fit: BoxFit.cover,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          " ",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 46, 46, 46),
          ),
        ),
      ),
    ],
  ),
),

        ],
      ),
    );
  }
}
