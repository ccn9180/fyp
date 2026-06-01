import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/gamification_service.dart';

class RewardStoreScreen extends StatefulWidget {
  const RewardStoreScreen({super.key});

  @override
  State<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends State<RewardStoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color accentGold = const Color(0xFFFFD700);

  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  Map<String, String> _rewardNamesCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRewardsCache();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load reward titles into a cache to easily resolve reward_id to name in history tab
  void _loadRewardsCache() async {
    final snap = await FirebaseFirestore.instance.collection('rewards').get();
    final Map<String, String> cache = {};
    for (final doc in snap.docs) {
      cache[doc.id] = doc.data()['name'] ?? 'Premium Reward';
    }
    if (mounted) {
      setState(() {
        _rewardNamesCache = cache;
      });
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'voucher':
      case 'ticket':
      case 'confirmation_number':
        return Icons.confirmation_number_rounded;
      case 'palette':
      case 'customization':
      case 'theme':
        return Icons.palette_rounded;
      case 'extension':
      case 'feature':
        return Icons.extension_rounded;
      case 'workspace_premium':
      case 'profile':
      case 'ribbon':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.redeem_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in.')),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('User details not found.')),
          );
        }

        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        final int coins = (userData['coins'] ?? 0) as int;
        final List<dynamic> redeemedRewards = userData['redeemed_rewards'] ?? [];

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'REWARDS & REDEMPTION',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: const Color(0xFF333333),
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              _buildBalanceHeader(coins),
              const SizedBox(height: 20),
              TabBar(
                controller: _tabController,
                labelColor: primaryGreen,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryGreen,
                isScrollable: false,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'AVAILABLE REWARDS'),
                  Tab(text: 'REDEMPTION HISTORY'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRewardsTab(coins, redeemedRewards),
                    _buildRedemptionHistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceHeader(int coins) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C9C84), Color(0xFF5B7563)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C9C84).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR BALANCE',
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    NumberFormat('#,###').format(coins),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'COINS',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsTab(int userCoins, List<dynamic> redeemedRewards) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rewards')
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No rewards available at the moment.',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          );
        }

        final rewards = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: rewards.length + 1,
          itemBuilder: (context, index) {
            if (index == rewards.length) {
              return _RecentRedemptionsAccordion(
                uid: uid ?? '',
                rewardNamesCache: _rewardNamesCache,
                primaryGreen: primaryGreen,
              );
            }
            final doc = rewards[index];
            final rewardId = doc.id;
            final reward = doc.data() as Map<String, dynamic>;
            final bool isRedeemed = redeemedRewards.contains(rewardId);

            return _buildRewardCard(reward, rewardId, userCoins, isRedeemed);
          },
        );
      },
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward, String rewardId, int userCoins, bool isRedeemed) {
    final int cost = (reward['coin_cost'] ?? 100) as int;
    final String category = reward['category'] ?? 'General';
    final iconData = _getIconData(reward['icon']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isRedeemed
                  ? Colors.grey[100]
                  : primaryGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              iconData,
              color: isRedeemed ? Colors.grey : primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward['name'] ?? 'Premium Reward',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isRedeemed ? Colors.grey : const Color(0xFF333333),
                    decoration: isRedeemed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  category,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$cost COINS',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isRedeemed ? Colors.grey : primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: isRedeemed ? null : () => _handleRedeem(reward, rewardId, cost, userCoins),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isRedeemed ? Colors.grey[300] : primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isRedeemed ? 'Claimed' : 'Redeem',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isRedeemed ? Colors.grey[600] : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('xp_logs')
          .doc(uid)
          .collection('entries')
          .where('source', isEqualTo: 'reward_redeemed')
          .orderBy('earned_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No redemptions yet',
                  style: GoogleFonts.outfit(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        final logs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final String rewardId = log['reward_id'] ?? '';
            final int spentCoins = (log['coins'] ?? 0) as int;
            final Timestamp? timestamp = log['earned_at'] as Timestamp?;
            final String dateStr = timestamp != null
                ? DateFormat('d MMM yyyy').format(timestamp.toDate())
                : 'Recent';

            // Resolve name from cache
            final String rewardName = _rewardNamesCache[rewardId] ?? 'Premium Reward';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.redeem_rounded, color: primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rewardName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        Text(
                          'Redemption Confirmed',
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$spentCoins COINS',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.red[300],
                        ),
                      ),
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleRedeem(Map<String, dynamic> reward, String rewardId, int coinCost, int userCoins) {
    if (userCoins < coinCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient coins to redeem this reward.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Icon(Icons.redeem_rounded, size: 64, color: primaryGreen),
            const SizedBox(height: 24),
            Text(
              'Redeem Reward?',
              style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Spend $coinCost coins to unlock "${reward['name'] ?? 'Premium Reward'}"?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _triggerRedemption(rewardId, coinCost);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm Redemption',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
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

  void _triggerRedemption(String rewardId, int coinCost) async {
    if (uid == null) return;
    
    final result = await GamificationService.redeemReward(uid!, rewardId, coinCost);
    if (!mounted) return;

    if (result['success'] == true) {
      _showSuccessDialog();
      _loadRewardsCache(); // Reload cache in case it changed
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['reason'] ?? 'Failed to redeem reward'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.check_circle_rounded, color: primaryGreen, size: 80),
            const SizedBox(height: 24),
            Text(
              'Reward Redeemed!',
              style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Congratulations! Your reward has been added to your profile.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Great!',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRedemptionsAccordion extends StatefulWidget {
  final String uid;
  final Map<String, String> rewardNamesCache;
  final Color primaryGreen;
  const _RecentRedemptionsAccordion({
    required this.uid,
    required this.rewardNamesCache,
    required this.primaryGreen,
  });

  @override
  State<_RecentRedemptionsAccordion> createState() => _RecentRedemptionsAccordionState();
}

class _RecentRedemptionsAccordionState extends State<_RecentRedemptionsAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Recent Redemptions',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF333333)),
            ),
            trailing: Icon(
              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: widget.primaryGreen,
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('xp_logs')
                        .doc(widget.uid)
                        .collection('entries')
                        .where('source', isEqualTo: 'reward_redeemed')
                        .orderBy('earned_at', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No recent redemptions',
                            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          ),
                        );
                      }
                      final logs = snapshot.data!.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index].data() as Map<String, dynamic>;
                          final String rewardId = log['reward_id'] ?? '';
                          final int spentCoins = (log['coins'] ?? 0) as int;
                          final String rewardName = widget.rewardNamesCache[rewardId] ?? 'Premium Reward';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    rewardName,
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$spentCoins Coins',
                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.red[300], fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

