import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:usb_serial/usb_serial.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '88 Cheers POS',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFFFFFBF0),
      ),
      home: const POSHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== DATABASE HELPER ====================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_88cheers_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final dbFilePath = path.join(dbPath, filePath);
    return await openDatabase(
      dbFilePath, 
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        walk_in_case REAL NOT NULL,
        walk_in_half REAL NOT NULL,
        delivery_case REAL NOT NULL,
        delivery_half REAL NOT NULL,
        category TEXT NOT NULL,
        image_path TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total REAL NOT NULL,
        amount_paid REAL NOT NULL,
        change_amount REAL NOT NULL,
        items TEXT NOT NULL,
        sale_type TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    // Insert products with prices from the image
    await db.insert('products', {
      'name': 'San Mig Lights',
      'walk_in_case': 1070.00,
      'walk_in_half': 537.00,
      'delivery_case': 1075.00,
      'delivery_half': 538.00,
      'category': 'Beer',
      'image_path': 'assets/images/sanmig_lights.png'
    });

    await db.insert('products', {
      'name': 'Pilsen',
      'walk_in_case': 930.00,
      'walk_in_half': 465.00,
      'delivery_case': 935.00,
      'delivery_half': 468.00,
      'category': 'Beer',
      'image_path': 'assets/images/pilsen.png'
    });

    await db.insert('products', {
      'name': 'Stallion',
      'walk_in_case': 993.00,
      'walk_in_half': 497.00,
      'delivery_case': 998.00,
      'delivery_half': 499.00,
      'category': 'Beer',
      'image_path': 'assets/images/stallion.png'
    });

    await db.insert('products', {
      'name': 'Red Horse 500',
      'walk_in_case': 695.00,
      'walk_in_half': 348.00,
      'delivery_case': 700.00,
      'delivery_half': 350.00,
      'category': 'Beer',
      'image_path': 'assets/images/redhorse500.png'
    });

    await db.insert('products', {
      'name': 'Red Horse Litro',
      'walk_in_case': 690.00,
      'walk_in_half': 345.00,
      'delivery_case': 695.00,
      'delivery_half': 348.00,
      'category': 'Beer',
      'image_path': 'assets/images/redhorse_litro.png'
    });
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert('products', product);
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.update('products', product, where: 'id = ?', whereArgs: [product['id']]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSale(Map<String, dynamic> sale) async {
    final db = await database;
    return await db.insert('sales', sale);
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await database;
    return await db.query('sales', orderBy: 'date DESC');
  }

  Future<int> deleteSale(int id) async {
    final db = await database;
    return await db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }
}

class Product {
  final int? id;
  final String name;
  final double walkInCase;
  final double walkInHalf;
  final double deliveryCase;
  final double deliveryHalf;
  final String imagePath;
  final String category;

  Product({
    this.id,
    required this.name,
    required this.walkInCase,
    required this.walkInHalf,
    required this.deliveryCase,
    required this.deliveryHalf,
    required this.imagePath,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'walk_in_case': walkInCase,
      'walk_in_half': walkInHalf,
      'delivery_case': deliveryCase,
      'delivery_half': deliveryHalf,
      'image_path': imagePath,
      'category': category,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: (map['name'] ?? '') as String,
      walkInCase: (map['walk_in_case'] ?? 0).toDouble(),
      walkInHalf: (map['walk_in_half'] ?? 0).toDouble(),
      deliveryCase: (map['delivery_case'] ?? 0).toDouble(),
      deliveryHalf: (map['delivery_half'] ?? 0).toDouble(),
      imagePath: (map['image_path'] ?? 'assets/images/placeholder.png') as String,
      category: (map['category'] ?? 'Uncategorized') as String,
    );
  }

  double getPrice(bool isDelivery, bool isCase) {
    if (isDelivery) {
      return isCase ? deliveryCase : deliveryHalf;
    } else {
      return isCase ? walkInCase : walkInHalf;
    }
  }
}

class CartItem {
  final Product product;
  int quantity;
  final bool isDelivery;
  final bool isCase; // true = 1 case, false = 1/2 case

  CartItem({
    required this.product, 
    this.quantity = 1, 
    required this.isDelivery,
    required this.isCase,
  });
  
  double get price => product.getPrice(isDelivery, isCase);
  double get total => price * quantity;
  String get sizeLabel => isCase ? '1 Case' : '1/2 Case';
}

class POSHomePage extends StatefulWidget {
  const POSHomePage({Key? key}) : super(key: key);

  @override
  State<POSHomePage> createState() => _POSHomePageState();
}

class _POSHomePageState extends State<POSHomePage> {
  List<Product> products = [];
  List<CartItem> cart = [];
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  UsbPort? connectedUsbPort;
  bool isConnected = false;
  String connectionType = 'None'; // 'Bluetooth', 'USB', or 'None'
  int _selectedIndex = 0;
  bool isDeliveryMode = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final productMaps = await DatabaseHelper.instance.getProducts();
    setState(() {
      products = productMaps.map((map) => Product.fromMap(map)).toList();
    });
  }

  void _showCaseSelectionDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select quantity:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildCaseOption(
              context, 
              product, 
              isCase: true, 
              label: '1 Case',
              price: product.getPrice(isDeliveryMode, true),
            ),
            const SizedBox(height: 12),
            _buildCaseOption(
              context, 
              product, 
              isCase: false, 
              label: '1/2 Case',
              price: product.getPrice(isDeliveryMode, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseOption(BuildContext context, Product product, {required bool isCase, required String label, required double price}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFDE68A), width: 2),
      ),
      child: InkWell(
        onTap: () {
          addToCart(product, isCase);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('₱${price.toStringAsFixed(2)}', 
                    style: const TextStyle(fontSize: 16, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                ],
              ),
              const Icon(Icons.arrow_forward_ios, color: Color(0xFFD97706)),
            ],
          ),
        ),
      ),
    );
  }

  void addToCart(Product product, bool isCase) {
    setState(() {
      var existingItem = cart.firstWhere(
        (item) => item.product.id == product.id && 
                  item.isDelivery == isDeliveryMode && 
                  item.isCase == isCase,
        orElse: () => CartItem(
          product: product, 
          quantity: 0, 
          isDelivery: isDeliveryMode,
          isCase: isCase,
        ),
      );
      if (existingItem.quantity > 0) {
        existingItem.quantity++;
      } else {
        cart.add(CartItem(
          product: product, 
          isDelivery: isDeliveryMode,
          isCase: isCase,
        ));
      }
    });
  }

  double getCartTotal() => cart.fold(0, (sum, item) => sum + item.total);
  int getCartItemCount() => cart.fold(0, (sum, item) => sum + item.quantity);

  Future<void> showPrinterConnectionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bluetooth, color: Colors.blue),
              title: const Text('Bluetooth Printer'),
              onTap: () => Navigator.pop(ctx, 'bluetooth'),
            ),
            ListTile(
              leading: const Icon(Icons.usb, color: Colors.green),
              title: const Text('USB Printer'),
              onTap: () => Navigator.pop(ctx, 'usb'),
            ),
          ],
        ),
      ),
    );

    if (result == 'bluetooth') {
      await connectToBluetoothPrinter();
    } else if (result == 'usb') {
      await connectToUsbPrinter();
    }
  }

  Future<void> connectToBluetoothPrinter() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        _showSnackBar('Bluetooth not supported');
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await Future.delayed(const Duration(seconds: 4));
      List<ScanResult> devices = FlutterBluePlus.lastScanResults;
      FlutterBluePlus.stopScan();

      Navigator.pop(context);

      if (devices.isEmpty) {
        _showSnackBar('No Bluetooth devices found');
        return;
      }

      BluetoothDevice? selectedDevice = await showDialog<BluetoothDevice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Bluetooth Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index].device;
                final name = device.advName.isNotEmpty 
                    ? device.advName 
                    : (device.platformName.isNotEmpty ? device.platformName : 'Unknown Device');
                return ListTile(
                  title: Text(name),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () => Navigator.pop(ctx, device),
                );
              },
            ),
          ),
        ),
      );

      if (selectedDevice != null) {
        await selectedDevice.connect();
        List<BluetoothService> services = await selectedDevice.discoverServices();
        for (var service in services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.write) {
              writeCharacteristic = characteristic;
              break;
            }
          }
          if (writeCharacteristic != null) break;
        }
        setState(() {
          connectedDevice = selectedDevice;
          isConnected = true;
          connectionType = 'Bluetooth';
          connectedUsbPort = null;
        });
        _showSnackBar('Bluetooth printer connected!');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Error: $e');
    }
  }

  Future<void> connectToUsbPrinter() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      List<UsbDevice> devices = await UsbSerial.listDevices();
      
      Navigator.pop(context);

      if (devices.isEmpty) {
        _showSnackBar('No USB devices found');
        return;
      }

      UsbDevice? selectedDevice = await showDialog<UsbDevice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select USB Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.productName ?? 'USB Device'),
                  subtitle: Text('Vendor ID: ${device.vid}, Product ID: ${device.pid}'),
                  onTap: () => Navigator.pop(ctx, device),
                );
              },
            ),
          ),
        ),
      );

      if (selectedDevice != null) {
        UsbPort? port = await selectedDevice.create();
        bool opened = await port!.open();
        
        if (opened) {
          await port.setDTR(true);
          await port.setRTS(true);
          await port.setPortParameters(
            9600, 
            UsbPort.DATABITS_8, 
            UsbPort.STOPBITS_1, 
            UsbPort.PARITY_NONE
          );
          
          setState(() {
            connectedUsbPort = port;
            isConnected = true;
            connectionType = 'USB';
            connectedDevice = null;
            writeCharacteristic = null;
          });
          _showSnackBar('USB printer connected!');
        } else {
          _showSnackBar('Failed to open USB connection');
        }
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('USB Error: $e');
    }
  }

Future<void> printCustomerReceipt(double amountPaid, double change, String saleType) async {
  // Show receipt preview immediately
  await _showReceiptPreview(amountPaid, change, saleType);
}

Future<void> _showReceiptPreview(double amountPaid, double change, String saleType) async {
  final total = getCartTotal();
  final now = DateTime.now();
  final dateFormat = DateFormat('MM/dd/yyyy');
  final timeFormat = DateFormat('hh:mm a');

  final shouldPrint = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Must choose Print or Skip
    builder: (ctx) => Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 400),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFD97706), Color(0xFFFBBF24)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text('Sale Completed!', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('88 CHEERS', 
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text('Wholesale Drinks & Beer', 
                        style: TextStyle(fontSize: 14)),
                      const Divider(height: 24),
                      const Text('** CUSTOMER COPY **', 
                        style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date: ${dateFormat.format(now)}'),
                          Text('Time: ${timeFormat.format(now)}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: saleType == 'Delivery' ? Colors.blue.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(saleType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ...cart.map((item) {
                        final priceType = item.isDelivery ? ' (D)' : ' (W)';
                        final sizeType = item.isCase ? ' - 1 Case' : ' - 1/2 Case';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.product.name}$priceType$sizeType',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('  ${item.quantity} x ₱${item.price.toStringAsFixed(2)}'),
                                  Text('₱${item.total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(height: 24),
                      _buildReceiptRow('TOTAL:', total),
                      _buildReceiptRow('PAID:', amountPaid),
                      _buildReceiptRow('CHANGE:', change, highlight: true),
                      const Divider(height: 24),
                      const Text('Thank you for your purchase!',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                      const Text('Please come again!',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 12),
                      const Text('(W) = Walk-in  (D) = Delivery',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFD97706), width: 2),
                      ),
                      child: const Text('Skip Print', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.print),
                      label: const Text('Print', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // If user chose to print
  if (shouldPrint == true) {
    await _printToPhysicalPrinter(amountPaid, change, saleType);
  }
}

Widget _buildReceiptRow(String label, double amount, {bool highlight = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: highlight ? 16 : 14,
          fontWeight: FontWeight.bold,
        )),
        Text('₱${amount.toStringAsFixed(2)}', style: TextStyle(
          fontSize: highlight ? 18 : 14,
          fontWeight: FontWeight.bold,
          color: highlight ? const Color(0xFFD97706) : null,
        )),
      ],
    ),
  );
}

Future<void> _printToPhysicalPrinter(double amountPaid, double change, String saleType) async {
  if (!isConnected) {
    _showSnackBar('Printer not connected - Receipt preview shown only');
    return;
  }

  try {
    String receipt = _generateReceipt(amountPaid, change, saleType);
    List<int> bytes = [];
    bytes.addAll([27, 64]); // Initialize
    bytes.addAll([27, 97, 1]); // Center align
    bytes.addAll(utf8.encode(receipt));
    bytes.addAll([27, 100, 3]); // Feed lines
    bytes.addAll([29, 86, 1]); // Cut paper

    if (connectionType == 'Bluetooth' && writeCharacteristic != null) {
      const chunkSize = 20;
      for (var i = 0; i < bytes.length; i += chunkSize) {
        var end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await writeCharacteristic!.write(bytes.sublist(i, end), withoutResponse: false);
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } else if (connectionType == 'USB' && connectedUsbPort != null) {
      await connectedUsbPort!.write(Uint8List.fromList(bytes));
    }

    _showSnackBar('Receipt printed successfully!');
  } catch (e) {
    _showSnackBar('Print error: $e');
  }
}

String _generateReceipt(double amountPaid, double change, String saleType) {
  final total = getCartTotal();
  final now = DateTime.now();
  final dateFormat = DateFormat('MM/dd/yyyy');
  final timeFormat = DateFormat('hh:mm a');
  
  String receipt = '\n================================\n';
  receipt += '         88 CHEERS\n';
  receipt += '    Wholesale Drinks & Beer\n';
  receipt += '================================\n';
  receipt += '     ** CUSTOMER COPY **\n';
  receipt += '================================\n';
  receipt += 'Date: ${dateFormat.format(now)}\n';
  receipt += 'Time: ${timeFormat.format(now)}\n';
  receipt += 'Type: $saleType\n';
  receipt += '================================\n\n';
  
  for (var item in cart) {
    final priceType = item.isDelivery ? ' (D)' : ' (W)';
    final sizeType = item.isCase ? ' - 1 Case' : ' - 1/2 Case';
    receipt += '${item.product.name}$priceType$sizeType\n';
    receipt += '  ${item.quantity} x P${item.price.toStringAsFixed(2)}';
    receipt += ' = P${item.total.toStringAsFixed(2)}\n\n';
  }
  
  receipt += '================================\n';
  receipt += 'TOTAL:        P${total.toStringAsFixed(2)}\n';
  receipt += 'PAID:         P${amountPaid.toStringAsFixed(2)}\n';
  receipt += 'CHANGE:       P${change.toStringAsFixed(2)}\n';
  receipt += '================================\n';
  receipt += '  Thank you for your purchase!\n';
  receipt += '      Please come again!\n';
  receipt += '================================\n';
  receipt += '(W) = Walk-in  (D) = Delivery\n';
  receipt += '================================\n\n\n';
  
  return receipt;
}
  Future<void> saveSaleToDatabase(double amountPaid, double change, String saleType) async {
    final items = cart.map((item) => {
      'name': item.product.name,
      'quantity': item.quantity,
      'price': item.price,
      'total': item.total,
      'type': item.isDelivery ? 'Delivery' : 'Walk-in',
      'size': item.isCase ? '1 Case' : '1/2 Case',
    }).toList();

    await DatabaseHelper.instance.insertSale({
      'total': getCartTotal(),
      'amount_paid': amountPaid,
      'change_amount': change,
      'items': jsonEncode(items),
      'sale_type': saleType,
      'date': DateTime.now().toIso8601String(),
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    connectedUsbPort?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFD97706), Color(0xFFFBBF24)]),
          ),
        ),
        title: const Text('88 CHEERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(
            icon: Icon(isConnected 
              ? (connectionType == 'Bluetooth' ? Icons.bluetooth_connected : Icons.usb)
              : Icons.print),
            tooltip: isConnected ? 'Connected via $connectionType' : 'Connect Printer',
            onPressed: showPrinterConnectionDialog,
          ),
          if (_selectedIndex == 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckoutPage(
                          cart: cart,
                          onUpdateCart: (updatedCart) => setState(() => cart = updatedCart),
                          onPrintReceipt: printCustomerReceipt,
                          onSaveSale: saveSaleToDatabase,
                        ),
                      ),
                    );
                  },
                ),
                if (getCartItemCount() > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text('${getCartItemCount()}', 
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ProductsPage(
            products: products, 
            onProductTap: _showCaseSelectionDialog,
            isDeliveryMode: isDeliveryMode,
            onToggleMode: (value) => setState(() => isDeliveryMode = value),
          ),
          ManageProductsPage(onProductsChanged: _loadProducts),
          SalesHistoryPage(key: ValueKey(_selectedIndex)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFFD97706),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Sell'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Sales'),
        ],
      ),
    );
  }
}

class ProductsPage extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;
  final bool isDeliveryMode;
  final Function(bool) onToggleMode;

  const ProductsPage({
    Key? key, 
    required this.products, 
    required this.onProductTap,
    required this.isDeliveryMode,
    required this.onToggleMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Products', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFFD97706), width: 2),
                ),
                child: Row(
                  children: [
                    _buildModeButton(context, 'Walk-in', !isDeliveryMode, () => onToggleMode(false)),
                    _buildModeButton(context, 'Delivery', isDeliveryMode, () => onToggleMode(true)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('No products available.\nAdd products in the Products tab.', textAlign: TextAlign.center))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product, 
                        onTap: () => onProductTap(product),
                        isDeliveryMode: isDeliveryMode,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(BuildContext context, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD97706) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF92400E),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isDeliveryMode;

  const ProductCard({
    Key? key, 
    required this.product, 
    required this.onTap,
    required this.isDeliveryMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final casePrice = product.getPrice(isDeliveryMode, true);
    final halfPrice = product.getPrice(isDeliveryMode, false);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFDE68A), width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: product.imagePath.startsWith('assets/')
                      ? Image.asset(
                          product.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                            );
                          },
                        )
                      : Image.memory(
                          base64Decode(product.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                            );
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, 
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), 
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Case: ₱${casePrice.toStringAsFixed(0)}', 
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                          Text('Half: ₱${halfPrice.toStringAsFixed(0)}', 
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDeliveryMode ? Colors.blue.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isDeliveryMode ? 'D' : 'W',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDeliveryMode ? Colors.blue.shade900 : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Select', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageProductsPage extends StatefulWidget {
  final VoidCallback onProductsChanged;

  const ManageProductsPage({Key? key, required this.onProductsChanged}) : super(key: key);

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  List<Product> products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final productMaps = await DatabaseHelper.instance.getProducts();
    setState(() {
      products = productMaps.map((map) => Product.fromMap(map)).toList();
    });
  }

  void _showProductDialog([Product? product]) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final walkInCaseController = TextEditingController(text: product?.walkInCase.toString() ?? '');
    final walkInHalfController = TextEditingController(text: product?.walkInHalf.toString() ?? '');
    final deliveryCaseController = TextEditingController(text: product?.deliveryCase.toString() ?? '');
    final deliveryHalfController = TextEditingController(text: product?.deliveryHalf.toString() ?? '');
    final categoryController = TextEditingController(text: product?.category ?? '');
    String selectedImagePath = product?.imagePath ?? '';
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Add Product' : 'Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      final bytes = await File(image.path).readAsBytes();
                      setDialogState(() {
                        selectedImagePath = base64Encode(bytes);
                      });
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD97706), width: 2),
                    ),
                    child: selectedImagePath.isEmpty
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                              SizedBox(height: 4),
                              Text('Add photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: selectedImagePath.startsWith('assets/')
                                ? Image.asset(selectedImagePath, fit: BoxFit.cover)
                                : Image.memory(base64Decode(selectedImagePath), fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                const Text('Walk-in Prices:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: walkInCaseController,
                        decoration: const InputDecoration(labelText: '1 Case *', prefixText: '₱', border: OutlineInputBorder(), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: walkInHalfController,
                        decoration: const InputDecoration(labelText: '1/2 Case *', prefixText: '₱', border: OutlineInputBorder(), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Delivery Prices:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: deliveryCaseController,
                        decoration: const InputDecoration(labelText: '1 Case *', prefixText: '₱', border: OutlineInputBorder(), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: deliveryHalfController,
                        decoration: const InputDecoration(labelText: '1/2 Case *', prefixText: '₱', border: OutlineInputBorder(), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || 
                    walkInCaseController.text.isEmpty || 
                    walkInHalfController.text.isEmpty ||
                    deliveryCaseController.text.isEmpty ||
                    deliveryHalfController.text.isEmpty ||
                    categoryController.text.isEmpty ||
                    selectedImagePath.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final newProduct = {
                  'name': nameController.text,
                  'walk_in_case': double.tryParse(walkInCaseController.text) ?? 0.0,
                  'walk_in_half': double.tryParse(walkInHalfController.text) ?? 0.0,
                  'delivery_case': double.tryParse(deliveryCaseController.text) ?? 0.0,
                  'delivery_half': double.tryParse(deliveryHalfController.text) ?? 0.0,
                  'category': categoryController.text,
                  'image_path': selectedImagePath,
                };

                if (product == null) {
                  await DatabaseHelper.instance.insertProduct(newProduct);
                } else {
                  newProduct['id'] = product.id!;
                  await DatabaseHelper.instance.updateProduct(newProduct);
                }

                widget.onProductsChanged();
                _loadProducts();
                Navigator.pop(ctx);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(product == null ? 'Product added!' : 'Product updated!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteProduct(product.id!);
      widget.onProductsChanged();
      _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Products', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              ElevatedButton.icon(
                onPressed: () => _showProductDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('No products yet.', textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: p.imagePath.startsWith('assets/')
                                  ? Image.asset(p.imagePath, fit: BoxFit.cover)
                                  : Image.memory(base64Decode(p.imagePath), fit: BoxFit.cover),
                            ),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('W: ₱${p.walkInCase.toStringAsFixed(0)}/₱${p.walkInHalf.toStringAsFixed(0)} | D: ₱${p.deliveryCase.toStringAsFixed(0)}/₱${p.deliveryHalf.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Color(0xFFD97706), size: 20), onPressed: () => _showProductDialog(p)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteProduct(p)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({Key? key}) : super(key: key);

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> sales = [];

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void didUpdateWidget(SalesHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSales();
  }

  Future<void> _loadSales() async {
    final salesData = await DatabaseHelper.instance.getSales();
    if (mounted) {
      setState(() {
        sales = salesData;
      });
    }
  }

  Future<void> _deleteSale(Map<String, dynamic> sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this sale?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount: ₱${sale['total'].toStringAsFixed(2)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Date: ${DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(sale['date']))}',
                    style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('This will be deducted from your total sales.',
              style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteSale(sale['id']);
      _loadSales();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale deleted! ₱${sale['total'].toStringAsFixed(2)} deducted from total.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSaleDetails(Map<String, dynamic> sale) {
    final items = (jsonDecode(sale['items']) as List).cast<Map<String, dynamic>>();
    final date = DateTime.parse(sale['date']);
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFD97706), Color(0xFFFBBF24)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sale Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteSale(sale);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MMM dd, yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(DateFormat('hh:mm a').format(date), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: sale['sale_type'] == 'Delivery' ? Colors.blue.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(sale['sale_type'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Divider(height: 24),
                      const Text('Items:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${item['size'] ?? ''} - ${item['type'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text('${item['quantity']} x ₱${(item['price'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            Text('₱${(item['total'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )).toList(),
                      const Divider(height: 24),
                      _buildTotalRow('Total:', sale['total']),
                      _buildTotalRow('Paid:', sale['amount_paid']),
                      _buildTotalRow('Change:', sale['change_amount'], highlight: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: highlight ? 16 : 14, fontWeight: FontWeight.bold)),
          Text('₱${amount.toStringAsFixed(2)}', style: TextStyle(
            fontSize: highlight ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFFD97706) : null,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    double totalSales = sales.fold(0, (sum, sale) => sum + sale['total']);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFFBBF24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Sales', style: TextStyle(fontSize: 16)),
                      Text('All Time', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                  Text('₱${totalSales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: sales.isEmpty
                ? const Center(child: Text('No sales yet.', textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      final date = DateTime.parse(sale['date']);
                      return Dismissible(
                        key: Key(sale['id'].toString()),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Sale'),
                              content: Text('Delete sale of ₱${sale['total'].toStringAsFixed(2)}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          await DatabaseHelper.instance.deleteSale(sale['id']);
                          _loadSales();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sale deleted! ₱${sale['total'].toStringAsFixed(2)} deducted.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.receipt, color: Color(0xFFD97706)),
                            ),
                            title: Row(
                              children: [
                                Text('₱${sale['total'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: sale['sale_type'] == 'Delivery' ? Colors.blue.shade100 : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(sale['sale_type'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(date)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFD97706)),
                            onTap: () => _showSaleDetails(sale),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  final List<CartItem> cart;
  final Function(List<CartItem>) onUpdateCart;
  final Function(double, double, String) onPrintReceipt;
  final Function(double, double, String) onSaveSale;

  const CheckoutPage({
    Key? key, 
    required this.cart, 
    required this.onUpdateCart, 
    required this.onPrintReceipt,
    required this.onSaveSale,
  }) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _amountController = TextEditingController();

  double getTotal() => widget.cart.fold(0, (sum, item) => sum + item.total);

  void updateQuantity(int index, int change) {
    setState(() {
      widget.cart[index].quantity += change;
      if (widget.cart[index].quantity <= 0) widget.cart.removeAt(index);
      widget.onUpdateCart(widget.cart);
    });
  }

  String getSaleType() {
    bool hasWalkIn = widget.cart.any((item) => !item.isDelivery);
    bool hasDelivery = widget.cart.any((item) => item.isDelivery);
    if (hasWalkIn && hasDelivery) return 'Mixed';
    if (hasDelivery) return 'Delivery';
    return 'Walk-in';
  }

  void processPayment() async {
    final total = getTotal();
    final amountPaid = double.tryParse(_amountController.text) ?? 0;
    
    if (amountPaid < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient payment!'), backgroundColor: Colors.red));
      return;
    }

    final change = amountPaid - total;
    final saleType = getSaleType();

    // Save to database first (Merchant digital copy)
    await widget.onSaveSale(amountPaid, change, saleType);

    // Show receipt preview directly (this calls the preview in POSHomePage)
    await widget.onPrintReceipt(amountPaid, change, saleType);

    // Clear cart and go back
    widget.cart.clear();
    widget.onUpdateCart(widget.cart);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = getTotal();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD97706), Color(0xFFFBBF24)]))),
        title: const Text('Checkout'),
      ),
      body: widget.cart.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text('Your cart is empty', style: TextStyle(fontSize: 20, color: Colors.grey)),
            ]))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.cart.length,
                    itemBuilder: (context, index) {
                      final item = widget.cart[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.product.imagePath.startsWith('assets/')
                                      ? Image.asset(item.product.imagePath, fit: BoxFit.cover)
                                      : Image.memory(base64Decode(item.product.imagePath), fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.isDelivery ? Colors.blue.shade100 : Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(item.isDelivery ? 'D' : 'W', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(item.sizeLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                    Text('₱${item.price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(onPressed: () => updateQuantity(index, -1), icon: const Icon(Icons.remove_circle_outline, size: 20), color: const Color(0xFFD97706)),
                                  Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  IconButton(onPressed: () => updateQuantity(index, 1), icon: const Icon(Icons.add_circle_outline, size: 20), color: const Color(0xFFD97706)),
                                ],
                              ),
                              Text('₱${item.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('₱${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount Paid',
                          prefixText: '₱',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: processPayment,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Complete Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}