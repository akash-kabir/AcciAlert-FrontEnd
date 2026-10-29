import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  String _normalizePhone(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return cleaned;

    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('00')) return '+${cleaned.substring(2)}';
    if (cleaned.length == 10) return '+91$cleaned';
    return '+$cleaned';
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    final result = await ApiService.getContacts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success && result.data != null) {
        _contacts = List<Map<String, dynamic>>.from(
          result.data!['contacts'] ?? [],
        );
      }
    });
  }

  Future<void> _deleteContact(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2229),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2C323B)),
        ),
        title: const Text('Delete Contact'),
        content: const Text(
          'Remove this emergency contact? They will no longer receive emergency alerts.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ApiService.deleteContact(id);
    if (!mounted) return;

    if (result.success) {
      _loadContacts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Contact deleted'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to delete'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _editContact(Map<String, dynamic> contact) async {
    final id = contact['id'];
    if (id is! int) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _ContactFormDialog(initialContact: contact),
    );

    if (result == null) return;

    final name = result['name'] ?? '';
    final phone = _normalizePhone(result['phone'] ?? '');
    final rel = result['relationship'];

    if (name.isEmpty || phone.isEmpty) return;

    final updateRes = await ApiService.updateContact(
      id: id,
      name: name,
      phone: phone,
      relationship: rel != null && rel.isNotEmpty ? rel : null,
    );

    if (!mounted) return;
    if (updateRes.success) {
      _loadContacts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Contact updated successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updateRes.error ?? 'Failed to update contact'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2229),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFF2C323B)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Add Emergency Contact',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select how you would like to add an emergency contact',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF14171C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C323B)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.contacts_rounded,
                          color: Colors.blueAccent,
                          size: 22,
                        ),
                      ),
                      title: const Text(
                        'Import from Phone',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Choose one or more contacts from your phonebook',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white38,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _importFromPhone();
                      },
                    ),
                    const Divider(color: Color(0xFF2C323B), height: 1, indent: 64),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      title: const Text(
                        'Add Manually',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Type name, phone number, and relationship',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white38,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddContactForm();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importFromPhone() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }

    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Contacts permission denied. Please grant permission in settings.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (!mounted) return;

    // Show loading while reading phone contacts
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Color(0xFF1E2229),
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(width: 20),
              Expanded(
                child: Text('Loading contacts...', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
    }

    if (!mounted) return;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No contacts found on this device'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final selected = await showDialog<List<Contact>>(
      context: context,
      builder: (ctx) => _PhoneContactPicker(contacts: contacts),
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    // Show progress dialog while importing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Color(0xFF1E2229),
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(width: 20),
              Expanded(
                child: Text('Importing selected contacts...', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );

    int addedCount = 0;
    int failedCount = 0;

    for (final contact in selected) {
      final phone = contact.phones.isNotEmpty
          ? _normalizePhone(contact.phones.first.number)
          : '';
      if (phone.isEmpty) {
        failedCount++;
        continue;
      }

      final contactName = contact.displayName.trim().isNotEmpty
          ? contact.displayName.trim()
          : 'Emergency Contact';

      final res = await ApiService.addContact(
        name: contactName,
        phone: phone,
      );

      if (res.success) {
        addedCount++;
      } else {
        failedCount++;
      }
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // dismiss progress dialog
    }

    if (!mounted) return;

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failedCount == 0
                ? 'Successfully imported $addedCount contact${addedCount > 1 ? "s" : ""}'
                : 'Imported $addedCount contact${addedCount > 1 ? "s" : ""} ($failedCount failed)',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _loadContacts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to import contacts. Please verify phone numbers.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showAddContactForm() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _ContactFormDialog(),
    );

    if (result == null || !mounted) return;

    final name = result['name'] ?? '';
    final phone = _normalizePhone(result['phone'] ?? '');
    final rel = result['relationship'];

    if (name.isEmpty || phone.isEmpty) return;

    final addRes = await ApiService.addContact(
      name: name,
      phone: phone,
      relationship: rel != null && rel.isNotEmpty ? rel : null,
    );

    if (!mounted) return;
    if (addRes.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $name to emergency contacts'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _loadContacts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(addRes.error ?? 'Failed to add contact'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildAvatar(String name, {double size = 42}) {
    final trimmed = name.trim();
    String initials = '?';
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (trimmed.isNotEmpty) {
        initials = trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    final colors = [
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFF673AB7),
      const Color(0xFFE91E63),
      const Color(0xFF2196F3),
      const Color(0xFFFF5722),
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
    ];
    final color = colors[trimmed.hashCode.abs() % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency Contacts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Contact',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F26),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2C323B)),
                        ),
                        child: const Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'No Emergency Contacts Yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Add trusted contacts who will receive emergency SOS alerts with your live location during a crash.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _showAddOptions,
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add First Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _contacts.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = _contacts[i];
                    final name = c['name'] as String? ?? 'Unknown';
                    final phone = c['phone'] as String? ?? '—';
                    final rel = c['relationship'] as String?;

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F26),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2C323B)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            _buildAvatar(name),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (rel != null && rel.trim().isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.15),
                                            ),
                                          ),
                                          child: Text(
                                            rel,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_rounded, size: 13, color: Colors.white38),
                                      const SizedBox(width: 5),
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.white60),
                                  onPressed: () => _editContact(c),
                                  tooltip: 'Edit contact',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                  onPressed: () => _deleteContact(c['id'] as int),
                                  tooltip: 'Delete contact',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Modern Dialog for adding or editing an emergency contact manually.
class _ContactFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialContact;

  const _ContactFormDialog({this.initialContact});

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _relationCtrl;

  final List<String> _quickRelationships = const [
    'Parent',
    'Spouse',
    'Sibling',
    'Friend',
    'Doctor',
    'Colleague',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.initialContact?['name'] as String? ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.initialContact?['phone'] as String? ?? '',
    );
    _relationCtrl = TextEditingController(
      text: widget.initialContact?['relationship'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.initialContact != null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'relationship': _relationCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2229),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF2C323B)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Icon(
                        _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Contact' : 'Add Contact',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isEditing
                                ? 'Update emergency contact details'
                                : 'Will receive emergency alerts & location',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Color(0xFF2C323B), height: 1),
                const SizedBox(height: 18),

                // Name field
                const Text(
                  'Full Name',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. John Doe',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: Colors.white54),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    if (v.trim().length < 2) {
                      return 'Name is too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone field
                const Text(
                  'Phone Number',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 9876543210 or +91...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                    prefixIcon: Icon(Icons.phone_outlined, size: 20, color: Colors.white54),
                    helperText: '10-digit numbers automatically get +91 prefix',
                    helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a phone number';
                    }
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 7) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Relationship field
                const Text(
                  'Relationship (Optional)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _relationCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Parent, Spouse, Friend',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                    prefixIcon: Icon(Icons.favorite_outline_rounded, size: 20, color: Colors.white54),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),

                // Quick relationship chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickRelationships.map((rel) {
                    final isSelected = _relationCtrl.text.trim().toLowerCase() == rel.toLowerCase();
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _relationCtrl.text = '';
                          } else {
                            _relationCtrl.text = rel;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : const Color(0xFF262C36),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.white : const Color(0xFF38404E),
                          ),
                        ),
                        child: Text(
                          rel,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Color(0xFF374151)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _isEditing ? 'Save Changes' : 'Add Contact',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern Dialog for importing contacts from device address book.
class _PhoneContactPicker extends StatefulWidget {
  final List<Contact> contacts;
  const _PhoneContactPicker({required this.contacts});

  @override
  State<_PhoneContactPicker> createState() => _PhoneContactPickerState();
}

class _PhoneContactPickerState extends State<_PhoneContactPicker> {
  final Set<String> _selectedIds = {};
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Contact> get _filtered {
    if (_search.trim().isEmpty) return widget.contacts;
    final q = _search.toLowerCase().trim();
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');

    return widget.contacts.where((c) {
      if (c.displayName.toLowerCase().contains(q)) return true;
      if (digits.isNotEmpty) {
        for (final p in c.phones) {
          final phoneDigits = p.number.replaceAll(RegExp(r'[^0-9]'), '');
          if (phoneDigits.contains(digits)) return true;
        }
      }
      return false;
    }).toList();
  }

  Widget _buildAvatar(String name) {
    final trimmed = name.trim();
    String initials = '?';
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (trimmed.isNotEmpty) {
        initials = trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    final colors = [
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFF673AB7),
      const Color(0xFFE91E63),
      const Color(0xFF2196F3),
      const Color(0xFFFF5722),
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
    ];
    final color = colors[trimmed.hashCode.abs() % colors.length];

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _toggleSelectAll(List<Contact> filtered) {
    setState(() {
      final allFilteredSelected = filtered.isNotEmpty && filtered.every((c) => _selectedIds.contains(c.id));
      if (allFilteredSelected) {
        for (final c in filtered) {
          _selectedIds.remove(c.id);
        }
      } else {
        for (final c in filtered) {
          _selectedIds.add(c.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final allFilteredSelected = filtered.isNotEmpty && filtered.every((c) => _selectedIds.contains(c.id));
    final mediaQuery = MediaQuery.of(context);
    final dialogHeight = (mediaQuery.size.height * 0.75).clamp(420.0, 620.0);

    return Dialog(
      backgroundColor: const Color(0xFF1E2229),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF2C323B)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        height: dialogHeight,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.contacts_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import Contacts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.contacts.length} contacts on phone',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or number...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.white54),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white54),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF14171C),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2C323B)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2C323B)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white, width: 1.2),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),

            // Filter actions bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectedIds.isNotEmpty
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFF252A32),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedIds.isNotEmpty
                          ? Colors.white.withValues(alpha: 0.3)
                          : const Color(0xFF333B46),
                    ),
                  ),
                  child: Text(
                    '${_selectedIds.length} selected',
                    style: TextStyle(
                      color: _selectedIds.isNotEmpty ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (filtered.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      allFilteredSelected
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 16,
                    ),
                    label: Text(
                      allFilteredSelected ? 'Deselect All' : 'Select All',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _toggleSelectAll(filtered),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: Color(0xFF2C323B), height: 1),
            const SizedBox(height: 6),

            // Contacts List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _search.isNotEmpty ? Icons.search_off_rounded : Icons.contacts_outlined,
                            size: 44,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _search.isNotEmpty
                                ? 'No contacts found matching "$_search"'
                                : 'No contacts available to import',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          if (_search.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                              child: const Text('Clear Search', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, index) => const Divider(
                        color: Color(0xFF252B33),
                        height: 1,
                        indent: 58,
                      ),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final isSelected = _selectedIds.contains(c.id);
                        final phone = c.phones.isNotEmpty
                            ? c.phones.first.number
                            : 'No phone number';

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(c.id);
                              } else {
                                _selectedIds.add(c.id);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                _buildAvatar(c.displayName),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.displayName.trim().isNotEmpty
                                            ? c.displayName
                                            : 'Unnamed Contact',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_rounded, size: 12, color: Colors.white38),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              phone,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 15,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2C323B), height: 1),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF374151)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () {
                            final picks = widget.contacts
                                .where((c) => _selectedIds.contains(c.id))
                                .toList();
                            Navigator.of(context).pop(picks);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                      disabledForegroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _selectedIds.isEmpty
                          ? 'Import'
                          : 'Import (${_selectedIds.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
