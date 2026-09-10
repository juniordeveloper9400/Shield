// Test-only fixture for the agent geographic hierarchy — a byte-for-byte
// copy of the old migration 0011 generated shape, kept only so the agent
// portal tests have a full multi-tier tree to exercise without a live
// database.
//
// Not used by the running app in any way: the real app starts with
// [GeoHierarchy.empty] and replaces it with the live `app.region` …
// `app.ward` tables (migration 0014) via [AgentGeo.ensureLoaded]. This lives
// under test/ specifically so nothing under lib/ can hardcode a fallback —
// see the header comment on lib/module/agent/agent_geo.dart.
//
// Usage in a test's setUp:
//   AgentGeo.instance.useHierarchy(GeoHierarchy.fromNodes(buildAgentGeoSeedNodes()));

import 'package:shield/data/neon/agent_geo_repository.dart';
import 'package:shield/module/agent/agent_model.dart' show AgentLevel;

const List<String> _seedRegions = [
  'North',
  'South',
  'East',
  'West',
  'Central',
  'Northeast',
];

const Map<String, List<String>> _seedRegionStates = {
  'North': [
    'Chandigarh',
    'Delhi',
    'Haryana',
    'Himachal Pradesh',
    'Jammu & Kashmir',
    'Ladakh',
    'Punjab',
    'Rajasthan',
  ],
  'South': ['Andhra Pradesh', 'Karnataka', 'Kerala', 'Tamil Nadu', 'Telangana'],
  'East': ['Bihar', 'Jharkhand', 'Odisha', 'West Bengal'],
  'West': ['Chhattisgarh', 'Goa', 'Gujarat', 'Maharashtra'],
  'Central': ['Madhya Pradesh', 'Uttar Pradesh', 'Uttarakhand'],
  'Northeast': [
    'Arunachal Pradesh',
    'Assam',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Sikkim',
    'Tripura',
  ],
};

const List<String> _seedKeralaDistricts = [
  'Thiruvananthapuram',
  'Kollam',
  'Pathanamthitta',
  'Alappuzha',
  'Kottayam',
  'Idukki',
  'Ernakulam',
  'Thrissur',
  'Palakkad',
  'Malappuram',
  'Kozhikode',
  'Wayanad',
  'Kannur',
  'Kasaragod',
];

/// Thiruvananthapuram's thirteen assembly segments plus the city corporation,
/// each with its printed code — the order is the seed's `sort`.
const List<List<String>> _seedTvmAssemblies = [
  ['Varkala', 'AC124'],
  ['Attingal', 'AC125'],
  ['Chirayinkeezhu', 'AC126'],
  ['Nedumangad', 'AC127'],
  ['Vamanapuram', 'AC128'],
  ['Kazhakkoottam', 'AC129'],
  ['Vattiyoorkavu', 'AC130'],
  ['Nemom', 'AC132'],
  ['Aruvikkara', 'AC133'],
  ['Parassala', 'AC134'],
  ['Kattakkada', 'AC135'],
  ['Kovalam', 'AC136'],
  ['Neyyattinkara', 'AC137'],
  ['Thiruvananthapuram Corporation', 'TVC'],
];

/// Varkala's (AC124) local bodies — six grama panchayats and the municipality
/// that carries [_seedVarkalaMunicipalityWards]; every other assembly segment
/// just gets three generic `<name> Panchayat n` LSGDs.
const List<String> _seedVarkalaLsgds = [
  'Chemmaruthy',
  'Edava',
  'Elakamon',
  'Madavoor',
  'Pallickal',
  'Vettoor',
  'Varkala Municipality',
];

/// The wards of Varkala Municipality, in order.
const List<String> _seedVarkalaMunicipalityWards = [
  'Vilakkulam',
  'Idapparambu',
  'Janathamukku',
  'Karunilakode',
  'Kallazhi',
  'Pullannikode',
  'Ayanikkuzhivila',
  'Kannamba',
  'Nadayara',
  'Kanwasramam',
  'Chaluvila',
  'Kallamkonam',
  'Cherukunnam',
  'Sivagiri',
  'Teachers Colony',
  'Raghunathapuram',
  'Puthenchantha',
  'Thachankonam',
  'Ramanthali',
  'Panayil',
  'Vallakkadavu',
  'Perumkulam',
  'Kottumoola',
  'Maithanam',
  'Municipal Office',
  'Hospital',
  'Temple',
  'Janardhanapuram / Papanasam',
  'Parayil / Mundayil',
  'Jawahar Park',
  'Punnamoodu',
  'Parayil',
  'Papanasam',
  'Kurakkanni',
];

String _slug(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');

String _pad(int n, int width) => n.toString().padLeft(width, '0');

/// Rebuilds the old migration 0011 rows in memory, for tests only.
List<GeoNode> buildAgentGeoSeedNodes() {
  final nodes = <GeoNode>[];

  for (var ri = 0; ri < _seedRegions.length; ri++) {
    final region = _seedRegions[ri];
    final regionId = 'geo/${_slug(region)}';
    nodes.add(GeoNode(
      id: regionId,
      parentId: null,
      level: AgentLevel.region,
      name: region,
      sort: ri + 1,
    ));

    final states = _seedRegionStates[region] ?? const <String>[];
    for (var si = 0; si < states.length; si++) {
      final state = states[si];
      final stateId = '$regionId/${_slug(state)}';
      nodes.add(GeoNode(
        id: stateId,
        parentId: regionId,
        level: AgentLevel.state,
        name: state,
        sort: si + 1,
      ));

      if (state != 'Kerala') continue;

      for (var di = 0; di < _seedKeralaDistricts.length; di++) {
        final district = _seedKeralaDistricts[di];
        final districtId = '$stateId/${_slug(district)}';
        nodes.add(GeoNode(
          id: districtId,
          parentId: stateId,
          level: AgentLevel.district,
          name: district,
          sort: di + 1,
        ));

        if (district != 'Thiruvananthapuram') continue;

        for (var ai = 0; ai < _seedTvmAssemblies.length; ai++) {
          final aname = _seedTvmAssemblies[ai][0];
          final acode = _seedTvmAssemblies[ai][1];
          final assemblyId = '$districtId/${_slug(aname)}';
          nodes.add(GeoNode(
            id: assemblyId,
            parentId: districtId,
            level: AgentLevel.assembly,
            name: aname,
            code: acode,
            sort: ai + 1,
          ));

          // The LSGDs under this assembly segment: Varkala names its six
          // grama panchayats + the municipality; the corporation segment is
          // its own single body; every other segment gets three generic
          // panchayats.
          final List<String> lsgds;
          if (acode == 'AC124') {
            lsgds = _seedVarkalaLsgds;
          } else if (acode == 'TVC') {
            lsgds = const ['Thiruvananthapuram Municipal Corporation'];
          } else {
            lsgds = [for (var li = 1; li <= 3; li++) '$aname Panchayat $li'];
          }

          for (var li = 0; li < lsgds.length; li++) {
            final lsgd = lsgds[li];
            final lcode = acode == 'TVC' ? 'TVC-L1' : '$acode-L${li + 1}';
            final lsgdId = '$assemblyId/${_slug(lsgd)}';
            nodes.add(GeoNode(
              id: lsgdId,
              parentId: assemblyId,
              level: AgentLevel.lsgd,
              name: lsgd,
              code: lcode,
              sort: li + 1,
            ));

            // Named wards for the two municipal bodies; generic numbered
            // wards for the panchayats.
            final List<String> wards;
            if (lsgd == 'Varkala Municipality') {
              wards = _seedVarkalaMunicipalityWards;
            } else if (acode == 'TVC') {
              wards = [
                for (var wi = 1; wi <= 100; wi++) '$lsgd Ward ${_pad(wi, 2)}',
              ];
            } else {
              wards = [
                for (var wi = 1; wi <= 12; wi++) '$lsgd Ward ${_pad(wi, 2)}',
              ];
            }

            for (var wi = 0; wi < wards.length; wi++) {
              nodes.add(GeoNode(
                id: '$lsgdId/ward-${_pad(wi + 1, 3)}',
                parentId: lsgdId,
                level: AgentLevel.ward,
                name: wards[wi],
                code: '$lcode-W${_pad(wi + 1, 3)}',
                sort: wi + 1,
              ));
            }
          }
        }
      }
    }
  }

  return nodes;
}
