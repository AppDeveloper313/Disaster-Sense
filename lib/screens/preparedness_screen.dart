import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PreparednessScreen extends StatelessWidget {
  const PreparednessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparedness & Emergency'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, 'Emergency Contacts', Icons.phone_in_talk, Colors.red),
          const SizedBox(height: 12),
          _buildEmergencyContacts(context),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'What to Do: Earthquakes', Icons.landslide, Colors.orange),
          const SizedBox(height: 12),
          _buildGuideSection(
            context,
            'Before',
            ['Secure heavy furniture to walls.', 'Create an emergency kit with food, water, and first aid.', 'Identify safe spots in each room (under sturdy tables).'],
          ),
          _buildGuideSection(
            context,
            'During',
            ['Drop, Cover, and Hold On.', 'Stay indoors if you are inside, avoid windows.', 'If outside, move away from buildings, trees, and power lines.'],
          ),
          _buildGuideSection(
            context,
            'After',
            ['Check yourself and others for injuries.', 'Expect aftershocks.', 'Listen to local news for updates and emergency instructions.'],
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'What to Do: Floods', Icons.water_drop, Colors.blue),
          const SizedBox(height: 12),
          _buildGuideSection(
            context,
            'Before',
            ['Know your area\'s flood risk and evacuation routes.', 'Keep important documents in a waterproof container.', 'Move valuables to higher floors.'],
          ),
          _buildGuideSection(
            context,
            'During',
            ['Move to higher ground immediately.', 'Do not walk or drive through floodwaters (Turn Around, Don\'t Drown).', 'Disconnect electrical appliances.'],
          ),
          _buildGuideSection(
            context,
            'After',
            ['Avoid moving water and stay out of damaged buildings.', 'Clean and disinfect everything that got wet.', 'Listen to authorities before returning home.'],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContacts(BuildContext context) {
    return Column(
      children: [
        _buildContactCard(context, 'Rescue 1122', 'Emergency Ambulance & Rescue', '1122'),
        _buildContactCard(context, 'Edhi Foundation', 'Ambulance Service', '115'),
        _buildContactCard(context, 'Police Helpline', 'Law Enforcement', '15'),
        _buildContactCard(context, 'Fire Brigade', 'Fire Emergency', '16'),
        _buildContactCard(context, 'PDMA', 'Disaster Management', '1129'),
      ],
    );
  }

  Widget _buildContactCard(BuildContext context, String name, String description, String number) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: const Icon(Icons.call),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: FilledButton.tonal(
          onPressed: () => _callNumber(number),
          child: const Text('Call'),
        ),
      ),
    );
  }

  Widget _buildGuideSection(BuildContext context, String phase, List<String> steps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phase,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              ...steps.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(child: Text(step)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callNumber(String number) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}
