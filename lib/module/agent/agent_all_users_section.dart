import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'agent_detail_screen.dart';
import 'agent_direct_sale.dart' show LevelBadge;
import 'agent_model.dart';
import 'agent_service.dart';

/// "All agents": every agent in the system, not just the viewer's own
/// downline — a flat directory so any agent can look up who is where.
///
/// Grouped by tier, national → ward, each row opening that agent's detail.
/// Rebuilds with the roster, so agents registered this session — and every
/// row folded in from `app.agent` on open — show up straight away.
class AgentAllUsersSection extends StatelessWidget {
  const AgentAllUsersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AgentService.instance,
      builder: (context, _) {
        final all = [...AgentService.instance.roster]
          ..sort((a, b) {
            final byLevel = a.level.index.compareTo(b.level.index);
            return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'All agents',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.offerTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${all.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Every registered agent, across the whole hierarchy.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            _AllAgentsList(agents: all),
          ],
        );
      },
    );
  }
}

class _AllAgentsList extends StatelessWidget {
  final List<Agent> agents;

  const _AllAgentsList({required this.agents});

  @override
  Widget build(BuildContext context) {
    if (agents.isEmpty) {
      return const Text(
        'No agents registered yet.',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < agents.length; i++)
            _AgentRow(agent: agents[i], topDivider: i != 0),
        ],
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  final Agent agent;
  final bool topDivider;

  const _AgentRow({required this.agent, required this.topDivider});

  @override
  Widget build(BuildContext context) {
    final approvalLabel = agent.isApproved
        ? null
        : agent.approvalStatus.label;

    return Column(
      children: [
        if (topDivider) const Divider(height: 1, color: AppColors.border),
        Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AgentDetailScreen(agent: agent),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: agent.active
                          ? AppColors.brandGreenDark
                          : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandBlue,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          [
                            agent.agentCode,
                            if (agent.area.isNotEmpty) agent.area,
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (approvalLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: agent.approvalStatus.tint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        approvalLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: agent.approvalStatus.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  LevelBadge(level: agent.level, size: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
