import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// ---------------- VALIDATION ----------------
bool isValidPhone(String phone) => RegExp(r'^[0-9]{10}$').hasMatch(phone);
bool isValidPassword(String password) =>
    RegExp(r'^(?=.*[A-Z])(?=.*[0-9]).{6,}$').hasMatch(password);

/// ---------------- MODELS ----------------
class AppUser {
  String email, password, name, phone, role;
  AppUser(
      {required this.email,
        required this.password,
        required this.name,
        required this.phone,
        this.role = 'user'});

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'name': name,
    'phone': phone,
    'role': role
  };

  static AppUser fromJson(Map<String, dynamic> m) => AppUser(
      email: m['email'],
      password: m['password'],
      name: m['name'],
      phone: m['phone'],
      role: m['role'] ?? 'user');
}

class Equipment {
  String name, location, ownerEmail;
  int price;

  Equipment(this.name, this.location, this.price, this.ownerEmail);

  Map<String, dynamic> toJson() =>
      {'name': name, 'location': location, 'price': price, 'ownerEmail': ownerEmail};

  static Equipment fromJson(Map<String, dynamic> m) =>
      Equipment(m['name'], m['location'], m['price'], m['ownerEmail']);
}

/// ---------------- PROVIDER ----------------
class AppProvider extends ChangeNotifier {
  AppUser? currentUser;
  List<AppUser> users = [];
  List<Equipment> equipments = [];
  List<Equipment> filtered = [];

  AppProvider() {
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    users = (jsonDecode(prefs.getString('users') ?? '[]') as List)
        .map((e) => AppUser.fromJson(e))
        .toList();

    if (!users.any((u) => u.email == 'admin@equip.com')) {
      users.add(AppUser(
          email: 'admin@equip.com',
          password: 'Admin@123',
          name: 'Admin',
          phone: '0000000000',
          role: 'admin'));
    }

    equipments = (jsonDecode(prefs.getString('equipments') ?? '[]') as List)
        .map((e) => Equipment.fromJson(e))
        .toList();

    filtered = equipments;
    saveData();
    notifyListeners();
  }

  void saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('users', jsonEncode(users.map((e) => e.toJson()).toList()));
    prefs.setString(
        'equipments', jsonEncode(equipments.map((e) => e.toJson()).toList()));
  }

  String? register(String email, String pass, String name, String phone) {
    if (!isValidPhone(phone)) return "Phone must be 10 digits";
    if (!isValidPassword(pass)) return "Password weak";
    users.add(AppUser(email: email, password: pass, name: name, phone: phone));
    saveData();
    notifyListeners();
    return null;
  }

  String? login(String email, String pass) {
    try {
      currentUser =
          users.firstWhere((u) => u.email == email && u.password == pass);
      notifyListeners();
      return null;
    } catch (_) {
      return "Invalid credentials";
    }
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  void addEquipment(Equipment e) {
    equipments.add(e);
    filtered = equipments;
    saveData();
    notifyListeners();
  }

  void updateEquipment(int index, Equipment e) {
    equipments[index] = e;
    filtered = equipments;
    saveData();
    notifyListeners();
  }

  void deleteEquipment(int index) {
    equipments.removeAt(index);
    filtered = equipments;
    saveData();
    notifyListeners();
  }

  void search(String query, String location) {
    filtered = equipments.where((e) {
      return e.name.toLowerCase().contains(query.toLowerCase()) &&
          (location.isEmpty ||
              e.location.toLowerCase() == location.toLowerCase());
    }).toList();
    notifyListeners();
  }
}

/// ---------------- MAIN ----------------
void main() {
  runApp(ChangeNotifierProvider(create: (_) => AppProvider(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Consumer<AppProvider>(
        builder: (_, app, __) =>
        app.currentUser == null ? const AuthScreen() : const HomePage(),
      ),
    );
  }
}

/// ---------------- AUTH UI ----------------
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Center(
          child: Card(
            elevation: 10,
            child: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: const [
                SizedBox(height: 10),
                Text("Farm Equipment Rent",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                TabBar(tabs: [Tab(text: "Login"), Tab(text: "Register")]),
                SizedBox(height: 350, child: TabBarView(children: [
                  LoginPage(),
                  RegisterPage(),
                ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------- LOGIN ----------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String email = '', pass = '', msg = '';
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        TextField(decoration: const InputDecoration(labelText: "Email"), onChanged: (v) => email = v),
        TextField(decoration: const InputDecoration(labelText: "Password"), obscureText: true, onChanged: (v) => pass = v),
        ElevatedButton(
            onPressed: () {
              msg = app.login(email, pass) ?? "";
              setState(() {});
            },
            child: const Text("Login")),
        Text(msg, style: const TextStyle(color: Colors.red)),
      ]),
    );
  }
}

/// ---------------- REGISTER ----------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String email = '', pass = '', name = '', phone = '', msg = '';
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        TextField(decoration: const InputDecoration(labelText: "Name"), onChanged: (v) => name = v),
        TextField(decoration: const InputDecoration(labelText: "Email"), onChanged: (v) => email = v),
        TextField(decoration: const InputDecoration(labelText: "Phone"), onChanged: (v) => phone = v),
        TextField(decoration: const InputDecoration(labelText: "Password"), obscureText: true, onChanged: (v) => pass = v),
        ElevatedButton(
            onPressed: () {
              msg = app.register(email, pass, name, phone) ?? "Registered Successfully";
              setState(() {});
            },
            child: const Text("Register")),
        Text(msg),
      ]),
    );
  }
}

/// ---------------- HOME ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchText = '', location = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.role == 'admin' ? "Admin Dashboard" : "Equipment Rent"),
        actions: [
          IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => app.logout())
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
                child: TextField(
                    decoration: const InputDecoration(hintText: "Equipment"),
                    onChanged: (v) => searchText = v)),
            const SizedBox(width: 5),
            Expanded(
                child: TextField(
                    decoration: const InputDecoration(hintText: "Location"),
                    onChanged: (v) => location = v)),
            ElevatedButton(
                onPressed: () => app.search(searchText, location),
                child: const Text("Search"))
          ]),
        ),
        ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Add Equipment"),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddEquipmentPage()))),
        Expanded(
          child: ListView.builder(
            itemCount: app.filtered.length,
            itemBuilder: (_, i) {
              final e = app.filtered[i];
              final isOwner = e.ownerEmail == user.email || user.role == 'admin';

              return Card(
                child: ListTile(
                  title: Text(e.name),
                  subtitle: Text("${e.location} • ₹${e.price}/day"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(
                        child: const Text("Rent"),
                        onPressed: () async {
                          final uri = Uri.parse(
                              "mailto:${e.ownerEmail}?subject=Rent Request&body=I want to rent ${e.name}");
                          await launchUrl(uri);
                        }),
                    if (isOwner)
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => app.deleteEquipment(i)),
                  ]),
                ),
              );
            },
          ),
        )
      ]),
    );
  }
}

/// ---------------- ADD EQUIPMENT ----------------
class AddEquipmentPage extends StatefulWidget {
  const AddEquipmentPage({super.key});
  @override
  State<AddEquipmentPage> createState() => _AddEquipmentPageState();
}

class _AddEquipmentPageState extends State<AddEquipmentPage> {
  final name = TextEditingController();
  final location = TextEditingController();
  final price = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("Add Equipment")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
          TextField(controller: location, decoration: const InputDecoration(labelText: "Location")),
          TextField(controller: price, decoration: const InputDecoration(labelText: "Price")),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () {
                app.addEquipment(Equipment(
                    name.text, location.text, int.parse(price.text), app.currentUser!.email));
                Navigator.pop(context);
              },
              child: const Text("Save"))
        ]),
      ),
    );
  }
}

/// ---------------- PROFILE ----------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.read<AppProvider>().currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Name: ${user.name}"),
          Text("Email: ${user.email}"),
          Text("Role: ${user.role}"),
          Text("Phone: ${user.phone}"),
        ]),
      ),
    );
  }
}
