import 'package:bulletin/student%20folder/functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentHomePage extends StatefulWidget {
  final String schoolId; // Id of the student

  const StudentHomePage({super.key, required this.schoolId});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  // State variables to store student's information
  String firstName = 'Loading...';
  String lastName = 'Loading...';
  String department = 'Loading...';
  String schoolId = 'Loading...';
  String email = 'Loading...';
  String? profileImageURL; // Variable to hold the profile image URL

  @override
  void initState() {
    super.initState();
    // Fetch student information from Firestore
    StudentFunctions.fetchStudentInfo(widget.schoolId,
        (fName, lName, ema, dept, id) {
      setState(() {
        firstName = fName;
        lastName = lName;
        email = ema;
        department = dept;
        schoolId = id;
      });
      _loadProfileImage();
    }, context);
  }

  // Method to load the profile image URL from Firestore
  Future<void> _loadProfileImage() async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('users_students') // Ensure correct collection name
          .doc(schoolId) // Use the student's ID as the document ID
          .get();

      if (studentDoc.exists) {
        if (studentDoc.data() != null &&
            studentDoc.data()!.containsKey('profileImageURL')) {
          String? imageUrl = studentDoc.data()!['profileImageURL'];
          if (isValidImageUrl(imageUrl)) {
            setState(() {
              profileImageURL = imageUrl;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  // Method to check if the image URL is valid
  bool isValidImageUrl(String? url) {
    return url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Home Page'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 20, // Adjust size as needed
              backgroundImage: profileImageURL != null &&
                      profileImageURL!.isNotEmpty
                  ? NetworkImage(profileImageURL!) // Use the profile image URL
                  : null, // No image will be displayed if URL is empty
              child: profileImageURL == null || profileImageURL!.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 24, // Adjust icon size if needed
                      color: Colors
                          .white, // Color of the icon when no image is available
                    )
                  : null, // No child if profile image exists
            ),
            onPressed: () {
              StudentFunctions.showProfileDialog(
                  context, firstName, lastName, email, department, schoolId);
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchAllAcceptedPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final acceptedPosts = snapshot.data ?? [];

                if (acceptedPosts.isEmpty) {
                  return const Center(
                      child: Text('No accepted posts available.'));
                }

                return ListView.builder(
                  itemCount: acceptedPosts.length,
                  itemBuilder: (context, index) {
                    final postData = acceptedPosts[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  postData['clubName'] ?? 'Unknown Club',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  postData['timestamp'] != null
                                      ? DateFormat('hh:mm a MMM dd yyyy')
                                          .format((postData['timestamp']
                                                  as Timestamp)
                                              .toDate())
                                      : 'N/A', // Use N/A if timestamp is null
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Displaying Post Title
                            Text(
                              postData['title'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Displaying Post Content
                            Text(
                              postData['content'] ?? 'N/A',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Function to fetch all accepted posts from specified departments
  Future<List<Map<String, dynamic>>> fetchAllAcceptedPosts() async {
    List<Map<String, dynamic>> acceptedPosts = [];

    // List of departments to fetch posts from
    List<String> departments = ['CAS', 'CED', 'CEAC', 'CBA', 'Non Academic'];

    for (String dept in departments) {
      // Fetching posts directly from the department's collection
      var postsSnapshot = await FirebaseFirestore.instance
          .collection(dept) // Assuming each department has its own collection
          .where('status', isEqualTo: 'Accepted')
          .get();

      for (var post in postsSnapshot.docs) {
        var postData = post.data();
        postData['clubName'] = postData['clubName'] ?? 'Unknown Club';
        postData['department'] = dept;
        acceptedPosts.add(postData);
      }
    }

    acceptedPosts.sort((a, b) {
      Timestamp timestampA = a['timestamp'] ?? Timestamp(0, 0);
      Timestamp timestampB = b['timestamp'] ?? Timestamp(0, 0);
      return timestampB.compareTo(timestampA); // Sort descending
    });

    return acceptedPosts;
  }
}
