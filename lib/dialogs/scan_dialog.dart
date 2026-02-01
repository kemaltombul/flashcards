import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../models/collection.dart';
import '../models/word.dart';

class ScanDialog extends StatefulWidget {
  final String? preselectedCollectionId;

  const ScanDialog({super.key, this.preselectedCollectionId});

  @override
  State<ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<ScanDialog> {
  final AIService _aiService = AIService();
  final FirestoreService _dbService = FirestoreService();

  File? _image;
  bool _isAnalyzing = false;
  bool _isProcessing = false;
  List<String> _detectedWords = [];
  final Set<String> _selectedWords = {};
  
  String? _selectedCollectionId;
  List<Collection> _collections = [];

  final ImagePicker _picker = ImagePicker();

  // Colors (matching app theme)
  final Color _backgroundColor = const Color(0xFF1E1E1E); // Slightly lighter for dialog
  final Color _cardColor = const Color(0xFF2C2C2C);
  final Color _accentColor = const Color(0xFFBB86FC);
  final TextStyle _textStyle = const TextStyle(fontFamily: 'Roboto', color: Colors.white);

  @override
  void initState() {
    super.initState();
    _selectedCollectionId = widget.preselectedCollectionId;
    _loadCollections();
  }

  // ... (keeping methods like _loadCollections, _pickImage, _analyzeImage, _processWords same, 
  // ensuring to check mounted before using context) 

  Future<void> _loadCollections() async {
    final cols = await _dbService.getCollections();
    if (!mounted) return;
    setState(() {
      _collections = cols;
      if (_selectedCollectionId == null && cols.isNotEmpty) {
        _selectedCollectionId = cols.first.id;
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _detectedWords = [];
          _selectedWords.clear();
          _isAnalyzing = true;
        });
        await _analyzeImage(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
      }
    }
  }

  Future<void> _analyzeImage(XFile imageFile) async {
    try {
      final words = await _aiService.extractWordsFromImage(imageFile);
      if (mounted) {
        if (words.isEmpty) {
          setState(() {
            _isAnalyzing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No underlined or highlighted words found found."), backgroundColor: Colors.orange));
        } else {
          setState(() {
            _detectedWords = words;
            _selectedWords.addAll(words); // Select all by default
            _isAnalyzing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Analysis failed: $e")));
      }
    }
  }

  Future<void> _processWords() async {
    if (_selectedWords.isEmpty || _selectedCollectionId == null) return;
    
    setState(() => _isProcessing = true);
    
    int success = 0;
    int failed = 0;
    
    for (String wordText in _selectedWords) {
      if (!mounted) break;
      try {
        final Map<String, dynamic> aiData = await _aiService.generateSmartWord(wordText, null, _selectedCollectionId!);
        
        final newWord = Word(
          collectionId: _selectedCollectionId!,
          word: aiData['word'],
          definition: aiData['definition'],
          meaningTr: aiData['meaning_tr'],
          example: aiData['example']
        );
        
        await _dbService.insertWord(newWord);
        success++;
      } catch (e) {
        failed++;
        print("Failed to add $wordText: $e");
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Added $success words${failed > 0 ? ', $failed failed' : ''}."),
          backgroundColor: success > 0 ? Colors.green : Colors.red,
        )
      );
      if (success > 0) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content
        children: [
          // Header with Close Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 10, 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Scan from Image", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          
          Flexible( // Allow scrolling within dialog
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
             // Collection Dropdown
             if (_collections.isNotEmpty)
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: DropdownButtonFormField<String>(
                   dropdownColor: _cardColor,
                   style: const TextStyle(color: Colors.white),
                   value: _selectedCollectionId,
                   decoration: InputDecoration(
                     filled: true,
                     fillColor: _cardColor,
                     labelText: "Target Collection",
                     labelStyle: TextStyle(color: _accentColor),
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   ),
                   items: _collections.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                   onChanged: (val) => setState(() => _selectedCollectionId = val),
                 ),
               ),

             // Image Preview
             if (_image != null)
               Container(
                 height: 300,
                 width: double.infinity,
                 margin: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   image: DecorationImage(image: FileImage(_image!), fit: BoxFit.cover),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: _isAnalyzing 
                     ? Center(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Text("Analyzing...", style: TextStyle(color: Colors.white))))
                     : null,
               )
             else
               GestureDetector(
                onTap: () => _pickImage(ImageSource.camera),
                 child: Container(
                   height: 200,
                   margin: const EdgeInsets.all(16),
                   decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                   child: Center(child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.camera_alt_outlined, size: 50, color: Colors.white24),
                       const SizedBox(height: 10),
                       Text("Tap to take photo", style: _textStyle.copyWith(color: Colors.white54)),
                     ],
                   )),
                 ),
               ),

             // Action Buttons
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 ElevatedButton.icon(
                   onPressed: () => _pickImage(ImageSource.camera),
                   icon: const Icon(Icons.camera_alt),
                   label: const Text("Camera"),
                   style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.black),
                 ),
                 const SizedBox(width: 20),
                 OutlinedButton.icon(
                   onPressed: () => _pickImage(ImageSource.gallery),
                   icon: const Icon(Icons.photo_library),
                   label: const Text("Gallery"),
                   style: OutlinedButton.styleFrom(foregroundColor: _accentColor, side: BorderSide(color: _accentColor)),
                 ),
               ],
             ),

             // Results List
             if (_detectedWords.isNotEmpty) ...[
               const Divider(color: Colors.white24, height: 40),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: Align(alignment: Alignment.centerLeft, child: Text("Detected Words (${_selectedWords.length})", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _accentColor))),
               ),
               ListView.builder(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: _detectedWords.length,
                 itemBuilder: (context, index) {
                   final word = _detectedWords[index];
                   final isSelected = _selectedWords.contains(word);
                   return CheckboxListTile(
                     title: Text(word, style: const TextStyle(color: Colors.white)),
                     value: isSelected,
                     activeColor: _accentColor,
                     checkColor: Colors.black,
                     onChanged: (val) {
                       setState(() {
                         if (val == true) {
                           _selectedWords.add(word);
                         } else {
                           _selectedWords.remove(word);
                         }
                       });
                     },
                   );
                 },
               ),
               
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: ElevatedButton(
                   onPressed: _isProcessing ? null : _processWords,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.green, 
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                   ),
                   child: _isProcessing 
                       ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                       : const Text("Add Selected Words", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                 ),
               ),
               const SizedBox(height: 50),
             ]
              ],
            ),
          ),
        ),
        ],
      ), 
    ); 
  }
}
