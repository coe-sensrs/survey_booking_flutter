import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step2StateDistrict extends ConsumerStatefulWidget {
  const Step2StateDistrict({super.key});

  @override
  ConsumerState<Step2StateDistrict> createState() => _Step2StateDistrictState();
}

class _Step2StateDistrictState extends ConsumerState<Step2StateDistrict> {
  List<String> _districts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/india_states_districts.json',
      );
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final statesList = data['states'] as List<dynamic>;

      final punjab = statesList.firstWhere(
        (s) => s['state'] == 'Punjab',
        orElse: () => statesList.first,
      );

      final districtList = (punjab['districts'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();

      setState(() {
        _districts = districtList;
        _isLoading = false;
      });

      final wizardState = ref.read(bookingWizardViewModelProvider);
      if (wizardState.district == null && _districts.isNotEmpty) {
        ref
            .read(bookingWizardViewModelProvider.notifier)
            .updateState(
              wizardState.copyWith(
                stateName: 'Punjab',
                district: _districts.first,
              ),
            );
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'State & District Selection',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Select the district in Punjab where the survey is required.',
            style: TextStyle(
              fontSize: 13.sp,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 20.h),

          // State Field (ReadOnly: Punjab)
          TextFormField(
            initialValue: 'Punjab',
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'State',
              prefixIcon: Icon(Icons.map),
            ),
          ),

          SizedBox(height: 16.h),

          // District Dropdown
          DropdownButtonFormField<String>(
            initialValue: _districts.contains(wizardState.district)
                ? wizardState.district
                : (_districts.isNotEmpty ? _districts.first : null),
            decoration: const InputDecoration(
              labelText: 'District *',
              prefixIcon: Icon(Icons.location_city),
            ),
            items: _districts.map((dist) {
              return DropdownMenuItem<String>(value: dist, child: Text(dist));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(bookingWizardViewModelProvider.notifier)
                    .updateState(
                      wizardState.copyWith(stateName: 'Punjab', district: val),
                    );
              }
            },
          ),
        ],
      ),
    );
  }
}
