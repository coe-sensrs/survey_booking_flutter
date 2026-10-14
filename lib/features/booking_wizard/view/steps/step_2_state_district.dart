import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../../../../core/providers/core_providers.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step2StateDistrict extends ConsumerWidget {
  const Step2StateDistrict({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final statesAsync = ref.watch(indiaStatesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final selectedState = wizardState.stateName;
    final isStateSelected = selectedState.trim().isNotEmpty;

    final districtsAsync = isStateSelected
        ? ref.watch(districtsForStateProvider(selectedState))
        : null;

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
            'Select the state/UT and district where the survey will be conducted.',
            style: TextStyle(
              fontSize: 13.sp,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 20.h),

          // ── State Dropdown ────────────────────────────────────────────────
          statesAsync.when(
            data: (states) {
              final isCurrentStateValid =
                  isStateSelected && states.contains(selectedState);

              return DropdownButtonFormField<String>(
                key: const ValueKey('state_dropdown'),
                isExpanded: true,
                initialValue: isCurrentStateValid ? selectedState : null,
                decoration: const InputDecoration(
                  labelText: 'State / Union Territory *',
                  hintText: 'Select State or UT',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: states.map((stateItem) {
                  return DropdownMenuItem<String>(
                    value: stateItem,
                    child: Text(stateItem, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(bookingWizardViewModelProvider.notifier)
                        .selectState(val);
                  }
                },
                onTap: () => FocusScope.of(context).unfocus(),
              );
            },
            loading: () {
              return DropdownButtonFormField<String>(
                key: const ValueKey('state_dropdown_loading'),
                isExpanded: true,
                initialValue: null,
                items: null,
                onChanged: null,
                decoration: InputDecoration(
                  labelText: 'State / Union Territory *',
                  hintText: 'Loading states & union territories...',
                  prefixIcon: const Icon(Icons.map_outlined),
                  suffixIcon: SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              );
            },
            error: (err, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('state_dropdown_error'),
                    isExpanded: true,
                    initialValue: null,
                    items: null,
                    onChanged: null,
                    decoration: InputDecoration(
                      labelText: 'State / Union Territory *',
                      hintText: 'Failed to load states',
                      prefixIcon: Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(indiaStatesProvider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry loading states'),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: 16.h),

          // ── District Dropdown (Cascading) ─────────────────────────────────
          if (!isStateSelected) ...[
            // Disabled when no state is selected
            DropdownButtonFormField<String>(
              key: const ValueKey('district_dropdown_disabled'),
              isExpanded: true,
              initialValue: null,
              items: null,
              onChanged: null,
              decoration: InputDecoration(
                labelText: 'District *',
                hintText: 'Select a state first',
                prefixIcon: const Icon(Icons.location_city_outlined),
                helperText: 'Select a state above to view available districts',
                helperStyle: TextStyle(
                  fontSize: 12.sp,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ] else if (districtsAsync != null) ...[
            districtsAsync.when(
              data: (districts) {
                final isCurrentDistrictValid =
                    wizardState.district != null &&
                    districts.contains(wizardState.district);

                return DropdownButtonFormField<String>(
                  key: ValueKey(
                    'district_dropdown_${selectedState}_${wizardState.district}',
                  ),
                  isExpanded: true,
                  initialValue: isCurrentDistrictValid
                      ? wizardState.district
                      : null,
                  decoration: InputDecoration(
                    labelText: 'District *',
                    hintText: districts.isEmpty
                        ? 'No districts available'
                        : 'Select District in $selectedState',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                  ),
                  items: districts.map((districtItem) {
                    return DropdownMenuItem<String>(
                      value: districtItem,
                      child: Text(
                        districtItem,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: districts.isEmpty
                      ? null
                      : (val) {
                          if (val != null) {
                            ref
                                .read(bookingWizardViewModelProvider.notifier)
                                .selectDistrict(val);
                          }
                        },
                  onTap: () => FocusScope.of(context).unfocus(),
                );
              },
              loading: () {
                return DropdownButtonFormField<String>(
                  key: const ValueKey('district_dropdown_loading'),
                  isExpanded: true,
                  initialValue: null,
                  items: null,
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'District *',
                    hintText: 'Loading districts for $selectedState...',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    suffixIcon: SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                );
              },
              error: (err, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('district_dropdown_error'),
                      isExpanded: true,
                      initialValue: null,
                      items: null,
                      onChanged: null,
                      decoration: InputDecoration(
                        labelText: 'District *',
                        hintText: 'Failed to load districts',
                        prefixIcon: Icon(
                          Icons.error_outline,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(
                        districtsForStateProvider(selectedState),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry loading districts'),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
