import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_colors.dart';
import 'agent_detail_screen.dart';
import 'agent_direct_sale.dart';
import 'agent_model.dart';
import 'agent_registration_screen.dart';
import 'agent_service.dart';

/// "My Team": the fixed shape of the org — every position it holds, filled
/// or not — drawn as a top-down chart. Each agent opens a fixed number of
/// positions at the tier below ([AgentLevel.childCapacity]: national → 2
/// region → 4 state → 8 district → 16 assembly → 32 lsgd → 64 ward). A
/// filled position is a card; an open one is a "+" in that tier's own colour
/// — not a name standing in for someone who was never registered — and
/// tapping it opens registration already pointed at the right parent and
/// tier. Balanced orthogonal connectors join every position to its parent,
/// filled or open alike, so the shape reads as one chart rather than as
/// cards with gaps between them.
///
/// Opens on the root's own card at full size near the top of the screen —
/// the one profile that matters on opening this screen — with the rest of
/// the chart running on below and out to both sides at that same natural
/// size: reached by scrolling and panning, not by shrinking the whole chart
/// down to fit the screen at once. The corner button offers that shrunk
/// whole-chart overview separately, for whenever an overview is worth more
/// than reading any one card.
class AgentTeamTreeScreen extends StatefulWidget {
  final Agent root;

  const AgentTeamTreeScreen({super.key, required this.root});

  @override
  State<AgentTeamTreeScreen> createState() => _AgentTeamTreeScreenState();
}

class _AgentTeamTreeScreenState extends State<AgentTeamTreeScreen> {
  /// Ids whose branch is folded away. Empty by default — every pre-built
  /// agent, national down to ward, is on the chart from the start, the way a
  /// real org chart is read: a caret is there for anyone who wants to tidy a
  /// branch out of the way, not because the chart withholds anything until
  /// asked.
  final Set<String> _collapsed = {};

  final _transform = TransformationController();

  /// Measures the laid-out chart so it can be positioned or shrunk to fit.
  final _chartKey = GlobalKey();

  /// The InteractiveViewer's own size, kept from the last layout.
  Size _viewportSize = Size.zero;

  /// True once the chart has been positioned at least once.
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openOnRoot());
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Where the screen opens: the root's own card, full size and near the top
  /// — the profile that matters on opening "My Team" — with the rest of the
  /// pre-built downline running on below and out to both sides at that same
  /// natural size, reached by scrolling and panning rather than by shrinking
  /// the whole chart down to fit the screen at once.
  ///
  /// The chart is laid out with the root centred over its own subtree (see
  /// the "balanced orthogonal connectors" on [_OrgTreeNode]), so the root's
  /// x is always the chart's own horizontal centre — which is what lets this
  /// centre the *root* by centring the whole, far wider, chart.
  void _openOnRoot() {
    final chartBox =
        _chartKey.currentContext?.findRenderObject() as RenderBox?;
    if (chartBox == null || !chartBox.hasSize || _viewportSize.isEmpty) {
      return;
    }
    final chartSize = chartBox.size;
    if (chartSize.width == 0 || chartSize.height == 0) {
      return;
    }

    const scale = 1.0;
    final dx = (_viewportSize.width - chartSize.width * scale) / 2;
    const dy = 24.0;

    setState(() {
      _transform.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
      _fitted = true;
    });
  }

  /// What the corner button asks for: the whole chart shrunk down to a
  /// single overview, however wide the downline has grown. Not the default
  /// view — see [_openOnRoot] — but there when an overview is worth more
  /// than reading any one card.
  void _fitToScreen() {
    final chartBox =
        _chartKey.currentContext?.findRenderObject() as RenderBox?;
    if (chartBox == null || !chartBox.hasSize || _viewportSize.isEmpty) {
      return;
    }
    final chartSize = chartBox.size;
    if (chartSize.width == 0 || chartSize.height == 0) {
      return;
    }

    final scaleX = (_viewportSize.width - 40) / chartSize.width;
    final scaleY = (_viewportSize.height - 60) / chartSize.height;
    final scale = math.min(math.min(scaleX, scaleY), 1.0);

    final dx = (_viewportSize.width - chartSize.width * scale) / 2;
    final dy = chartSize.height * scale < _viewportSize.height
        ? math.max(24.0, (_viewportSize.height - chartSize.height * scale) / 4)
        : 24.0;

    setState(() {
      _transform.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
      _fitted = true;
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_collapsed.remove(id)) {
        _collapsed.add(id);
      }
    });
  }

  Future<void> _addUnder(Agent parent) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AgentRegistrationScreen(
          scopeRoot: widget.root,
          initialParent: parent,
        ),
      ),
    );
    if (added != true || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Agent registered')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'My Team',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fitToScreen,
            icon: const Icon(Icons.center_focus_strong_rounded),
            color: AppColors.textMuted,
            tooltip: 'Fit whole team',
          ),
          IconButton(
            onPressed: () => _addUnder(widget.root),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            color: AppColors.brandBlue,
            tooltip: 'Add agent',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListenableBuilder(
        listenable: AgentService.instance,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            _viewportSize = constraints.biggest;
            return ClipRect(
              child: AnimatedOpacity(
                opacity: _fitted ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(500),
                  minScale: 0.1,
                  maxScale: 3.5,
                  child: Padding(
                    key: _chartKey,
                    padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
                    child: _OrgTreeNode(
                      // Re-read rather than trusting widget.root as-is: a
                      // photo added to the root from its own detail screen
                      // would otherwise never show here, since widget.root
                      // is fixed at push time and everyone else in the tree
                      // is read fresh off the service on every rebuild.
                      agent: AgentService.instance.byId(widget.root.id) ??
                          widget.root,
                      collapsed: _collapsed,
                      onToggle: _toggle,
                      onOpen: (agent) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AgentDetailScreen(agent: agent),
                        ),
                      ),
                      onAdd: _addUnder,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Color theme for hierarchy levels matching the reference design.
Color _tierColor(AgentLevel level) {
  switch (level) {
    case AgentLevel.national:
      return const Color(0xFF8E343A); // Deep Maroon / Burgundy
    case AgentLevel.region:
      return const Color(0xFF1E3A5F); // Dark Navy Blue
    case AgentLevel.state:
      return const Color(0xFFBE9B4B); // Ochre / Warm Gold
    case AgentLevel.district:
      return const Color(0xFF6B8E4E); // Olive Green
    case AgentLevel.assembly:
      return const Color(0xFF5C768D); // Slate Grey-Blue
    case AgentLevel.lsgd:
      return const Color(0xFF4A6F70); // Slate Teal
    case AgentLevel.ward:
      return const Color(0xFF607D8B); // Steel Grey
  }
}

/// One node and its recursive subtree.
class _OrgTreeNode extends StatelessWidget {
  final Agent agent;
  final Set<String> collapsed;
  final void Function(String id) onToggle;
  final void Function(Agent agent) onOpen;
  final void Function(Agent parent) onAdd;

  const _OrgTreeNode({
    required this.agent,
    required this.collapsed,
    required this.onToggle,
    required this.onOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final service = AgentService.instance;
    final children = service.childrenOf(agent.id);
    final capacity = agent.level.childCapacity;
    final childLevel = agent.level.child;
    final folded = collapsed.contains(agent.id);
    // Every position under this agent shows, filled or not — that is the
    // whole point of a fixed-shape chart. Only folding it away hides them.
    final showPositions = capacity > 0 && !folded;
    final color = _tierColor(agent.level);

    return _OrgSubtree(
      connectorColor: color,
      siblingGap: 24,
      stemHeight: 22,
      dropHeight: 22,
      card: _NodeCard(
        agent: agent,
        folded: folded,
        onToggle: capacity == 0 ? null : () => onToggle(agent.id),
        onOpen: () => onOpen(agent),
        // Adding now happens by tapping the specific open position, not a
        // shortcut on the filled card next to it — see [_EmptySlotNode].
        onAdd: null,
      ),
      children: showPositions
          ? [
              for (final child in children)
                _OrgTreeNode(
                  agent: child,
                  collapsed: collapsed,
                  onToggle: onToggle,
                  onOpen: onOpen,
                  onAdd: onAdd,
                ),
              // The positions this agent's own children have not filled yet —
              // fillable straight away, since [agent] standing here is real.
              for (var i = children.length; i < capacity; i++)
                _EmptySlotNode(
                  level: childLevel!,
                  fillable: true,
                  onAdd: () => onAdd(agent),
                ),
            ]
          : const [],
    );
  }
}

/// One position on the fixed org shape that nobody has been registered into
/// yet, drawn where that agent would otherwise sit rather than a name
/// standing in for someone who is not there — and, since the shape is fixed,
/// every tier under it drawn the same way in turn, all the way to ward,
/// whether or not anyone has filled the tiers in between.
///
/// Only [fillable] slots — the ones sitting directly under a real agent —
/// open registration when tapped. A district slot hanging under an
/// still-empty region slot is shown so the shape reads true, but there is no
/// real state agent yet to register it under; tapping it says so instead of
/// opening a form with nowhere valid to save to.
class _EmptySlotNode extends StatelessWidget {
  final AgentLevel level;
  final bool fillable;
  final VoidCallback onAdd;

  const _EmptySlotNode({
    required this.level,
    required this.fillable,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final capacity = level.childCapacity;
    final childLevel = level.child;

    return _OrgSubtree(
      connectorColor: _tierColor(level).withValues(alpha: 0.5),
      siblingGap: 24,
      stemHeight: 22,
      dropHeight: 22,
      card: _PlusSlotCard(level: level, fillable: fillable, onAdd: onAdd),
      children: capacity > 0
          ? [
              for (var i = 0; i < capacity; i++)
                _EmptySlotNode(
                  level: childLevel!,
                  // Nothing below an already-unfillable slot is fillable
                  // either — there is no real agent anywhere above it yet.
                  fillable: false,
                  onAdd: onAdd,
                ),
            ]
          : const [],
    );
  }
}

/// The "+" itself: an open, unnamed position at [level], in that tier's own
/// colour so an empty region slot and an empty ward slot still read as
/// different tiers even with nobody in either of them. Dimmer, and without
/// the "+" mark, when [fillable] is false — a preview of the shape rather
/// than something there is anything to do here yet.
class _PlusSlotCard extends StatelessWidget {
  final AgentLevel level;
  final bool fillable;
  final VoidCallback onAdd;

  const _PlusSlotCard({
    required this.level,
    required this.fillable,
    required this.onAdd,
  });

  void _explainWhyNot(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Register the ${level.parent?.label ?? level.label} above this '
          'position first',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(level);
    final alpha = fillable ? 1.0 : 0.45;

    return Tooltip(
      message: fillable
          ? 'Add a ${level.label.toLowerCase()} agent here'
          : '${level.label} position — not open yet',
      child: Material(
        color: color.withValues(alpha: 0.06 * alpha),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: fillable ? onAdd : () => _explainWhyNot(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: _NodeCard._cardWidth,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.55 * alpha),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  fillable ? Icons.add_rounded : Icons.lock_outline_rounded,
                  size: fillable ? 22 : 16,
                  color: color.withValues(alpha: alpha),
                ),
                const SizedBox(height: 3),
                Text(
                  level.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: color.withValues(alpha: alpha),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One agent card on the chart:
/// - Circular profile avatar with level-colored border ring
/// - Solid card in level-colored background with bold white name and position
/// - Active status dot & add agent shortcut
/// - Branch expand / collapse chevron
class _NodeCard extends StatelessWidget {
  final Agent agent;
  final bool folded;
  final VoidCallback? onToggle;
  final VoidCallback onOpen;
  final VoidCallback? onAdd;

  const _NodeCard({
    required this.agent,
    required this.folded,
    required this.onToggle,
    required this.onOpen,
    required this.onAdd,
  });

  static const double _circleSize = 44;
  static const double _markBox = _circleSize + 14;
  static const double _cardWidth = 94;
  static const double _overlap = 16;

  @override
  Widget build(BuildContext context) {
    final initials = agent.initials;
    final showInitials = initials.length >= 2;
    final accent = _tierColor(agent.level);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // The solid name/position card dropped behind the avatar
            Container(
              margin: const EdgeInsets.only(top: _markBox - _overlap),
              width: _cardWidth,
              padding: const EdgeInsets.fromLTRB(6, _overlap + 3, 6, 8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: onOpen,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      agent.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agent.level.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: AppColors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      agent.agentCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: AppColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    // Approved is the ordinary state and says nothing extra;
                    // this only shows up for the recruit still waiting on
                    // their parent, or the one who was turned away.
                    if (!agent.isApproved) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          agent.approvalStatus.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: agent.approvalStatus.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // The round profile head riding the top edge of the card
            SizedBox(
              width: _markBox,
              height: _markBox,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Semantics(
                      button: true,
                      label: '${agent.name}, ${agent.level.label}',
                      child: Material(
                        key: ValueKey('node-circle-${agent.id}'),
                        color: AppColors.white,
                        shape: CircleBorder(
                          side: BorderSide(color: accent, width: 2.5),
                        ),
                        elevation: 2,
                        shadowColor: Colors.black26,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onOpen,
                          child: SizedBox(
                            width: _circleSize,
                            height: _circleSize,
                            child: Center(
                              child: AgentPhotoFace(
                                photoBytes: agent.photoBytes,
                                size: _circleSize,
                                fallback: showInitials
                                    ? Text(
                                        initials,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: accent,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person_rounded,
                                        size: 22,
                                        color: accent.withValues(alpha: 0.85),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Active status indicator dot
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: agent.active
                            ? AppColors.brandGreenDark
                            : AppColors.textMuted,
                        border: Border.all(
                          color: AppColors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Add under parent badge
                  if (onAdd != null)
                    Positioned(
                      left: 2,
                      top: 1,
                      child: Tooltip(
                        message: 'Add under ${agent.name}',
                        child: Material(
                          color: AppColors.brandBlue,
                          shape: const CircleBorder(
                            side: BorderSide(
                              color: AppColors.white,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onAdd,
                            child: const SizedBox(
                              width: 18,
                              height: 18,
                              child: Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (onToggle != null)
          Tooltip(
            message: folded ? 'Expand ${agent.name}' : 'Collapse ${agent.name}',
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                child: Icon(
                  folded
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                  size: 16,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom layout for a node and its child subtrees ensuring:
/// 1. Symmetrical left and right horizontal connector line lengths.
/// 2. Parent node positioned exactly at the horizontal midpoint between the
///    first and last child nodes.
/// 3. Crisp orthogonal connector lines colored in the parent's tier accent.
class _OrgSubtree extends MultiChildRenderObjectWidget {
  final Color connectorColor;
  final double siblingGap;
  final double stemHeight;
  final double dropHeight;

  _OrgSubtree({
    super.key,
    required Widget card,
    required List<Widget> children,
    required this.connectorColor,
    this.siblingGap = 24,
    this.stemHeight = 22,
    this.dropHeight = 22,
  }) : super(children: [card, ...children]);

  @override
  _RenderOrgTree createRenderObject(BuildContext context) {
    return _RenderOrgTree(
      connectorColor: connectorColor,
      siblingGap: siblingGap,
      stemHeight: stemHeight,
      dropHeight: dropHeight,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderOrgTree renderObject) {
    renderObject
      ..connectorColor = connectorColor
      ..siblingGap = siblingGap
      ..stemHeight = stemHeight
      ..dropHeight = dropHeight;
  }
}

class _OrgTreeParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderOrgTree extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OrgTreeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OrgTreeParentData> {
  Color connectorColor;
  double siblingGap;
  double stemHeight;
  double dropHeight;

  /// The horizontal center of the node card relative to this subtree's origin.
  double nodeCenterX = 0.0;

  _RenderOrgTree({
    required this.connectorColor,
    required this.siblingGap,
    required this.stemHeight,
    required this.dropHeight,
  });

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OrgTreeParentData) {
      child.parentData = _OrgTreeParentData();
    }
  }

  @override
  void performLayout() {
    if (firstChild == null) {
      size = constraints.smallest;
      nodeCenterX = 0;
      return;
    }

    final parentCard = firstChild!;
    parentCard.layout(const BoxConstraints(), parentUsesSize: true);

    final children = <_RenderOrgTree>[];
    var child = (parentCard.parentData as _OrgTreeParentData).nextSibling;
    while (child != null) {
      if (child is _RenderOrgTree) {
        child.layout(const BoxConstraints(), parentUsesSize: true);
        children.add(child);
      }
      child = (child.parentData as _OrgTreeParentData).nextSibling;
    }

    if (children.isEmpty) {
      size = parentCard.size;
      nodeCenterX = size.width / 2.0;
      (parentCard.parentData as _OrgTreeParentData).offset = Offset.zero;
      return;
    }

    // Measure children row widths and calculate relative child origins
    final childOffsetsX = <double>[];
    double currentX = 0;
    for (var i = 0; i < children.length; i++) {
      childOffsetsX.add(currentX);
      currentX += children[i].size.width;
      if (i < children.length - 1) {
        currentX += siblingGap;
      }
    }
    final totalChildrenWidth = currentX;

    // Centers of first and last child nodes relative to the children row
    final firstCenter = childOffsetsX.first + children.first.nodeCenterX;
    final lastCenter = childOffsetsX.last + children.last.nodeCenterX;
    final mid = (firstCenter + lastCenter) / 2.0;

    // Pad left/right if the parent card is wider than the mid offset
    final leftPadding = math.max(0.0, parentCard.size.width / 2.0 - mid);
    final rightPadding = math.max(
      0.0,
      parentCard.size.width / 2.0 - (totalChildrenWidth - mid),
    );

    final totalWidth = totalChildrenWidth + leftPadding + rightPadding;
    nodeCenterX = leftPadding + mid;

    // Position parent card centered directly at nodeCenterX (the exact mid-point)
    (parentCard.parentData as _OrgTreeParentData).offset = Offset(
      nodeCenterX - parentCard.size.width / 2.0,
      0,
    );

    final connectorTotalHeight = stemHeight + dropHeight;
    final childrenY = parentCard.size.height + connectorTotalHeight;

    double maxChildHeight = 0;
    for (var i = 0; i < children.length; i++) {
      (children[i].parentData as _OrgTreeParentData).offset = Offset(
        leftPadding + childOffsetsX[i],
        childrenY,
      );
      maxChildHeight = math.max(maxChildHeight, children[i].size.height);
    }

    size = Size(totalWidth, childrenY + maxChildHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final parentCard = firstChild;
    if (parentCard == null) return;

    final children = <_RenderOrgTree>[];
    var child = (parentCard.parentData as _OrgTreeParentData).nextSibling;
    while (child != null) {
      if (child is _RenderOrgTree) {
        children.add(child);
      }
      child = (child.parentData as _OrgTreeParentData).nextSibling;
    }

    // Paint orthogonal connector lines behind nodes
    if (children.isNotEmpty) {
      final canvas = context.canvas;
      final linePaint = Paint()
        ..color = connectorColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;

      final parentBottomCenter = offset + Offset(nodeCenterX, parentCard.size.height);
      final busY = parentBottomCenter.dy + stemHeight;

      // 1. Vertical stem from bottom of parent to bus line
      canvas.drawLine(
        parentBottomCenter,
        Offset(parentBottomCenter.dx, busY),
        linePaint,
      );

      if (children.length == 1) {
        // Single child: straight line from bus to child top center
        final childParentData = children.first.parentData as _OrgTreeParentData;
        final childTopCenter = offset + Offset(
          childParentData.offset.dx + children.first.nodeCenterX,
          childParentData.offset.dy,
        );
        canvas.drawLine(
          Offset(parentBottomCenter.dx, busY),
          childTopCenter,
          linePaint,
        );
      } else {
        // Multiple children:
        // Horizontal bus extending from first child center to last child center
        final firstChildData = children.first.parentData as _OrgTreeParentData;
        final lastChildData = children.last.parentData as _OrgTreeParentData;
        final firstX =
            offset.dx + firstChildData.offset.dx + children.first.nodeCenterX;
        final lastX =
            offset.dx + lastChildData.offset.dx + children.last.nodeCenterX;

        canvas.drawLine(Offset(firstX, busY), Offset(lastX, busY), linePaint);

        // Vertical drop lines into each child
        for (final c in children) {
          final cData = c.parentData as _OrgTreeParentData;
          final childX = offset.dx + cData.offset.dx + c.nodeCenterX;
          final childY = offset.dy + cData.offset.dy;
          canvas.drawLine(Offset(childX, busY), Offset(childX, childY), linePaint);
        }
      }
    }

    // Paint parent card
    final cardParentData = parentCard.parentData as _OrgTreeParentData;
    context.paintChild(parentCard, offset + cardParentData.offset);

    // Paint child subtrees
    for (final c in children) {
      final cData = c.parentData as _OrgTreeParentData;
      context.paintChild(c, offset + cData.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
