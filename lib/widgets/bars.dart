import 'package:flutter/material.dart';

class StarRow extends StatelessWidget {
  final int stars;
  final double size;
  const StarRow(this.stars, {super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [0, 1, 2]
          .map((i) => Icon(
                i < stars ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: size,
              ))
          .toList(),
    );
  }
}

class HeartsBar extends StatelessWidget {
  final int hearts;
  const HeartsBar(this.hearts, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [0, 1, 2]
          .map((i) => Icon(
                Icons.favorite,
                color: i < hearts ? Colors.red : Colors.grey.shade300,
                size: 26,
              ))
          .toList(),
    );
  }
}

class CoinsBadge extends StatelessWidget {
  final int coins;
  const CoinsBadge(this.coins, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
        const SizedBox(width: 4),
        Text(coins.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
