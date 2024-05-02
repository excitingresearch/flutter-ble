import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async'; // Import the dart:async library

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ParticleScreen(),
    );
  }
}

class ParticleScreen extends StatefulWidget {
  @override
  _ParticleScreenState createState() => _ParticleScreenState();
}

class _ParticleScreenState extends State<ParticleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _generateParticles();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final Random _random = Random();

  void _generateParticles() {
    Timer.periodic(Duration(milliseconds: 500), (_) {
      setState(() {
        // Top Particles
        _particles.add(Particle(_random, direction: 'down'));

        // Bottom Particles (Unchanged)
        _particles.add(Particle(_random));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: Colors.blueGrey),
        child: CustomPaint(
          foregroundPainter: ParticlePainter(_particles, _controller),
        ),
      ),
    );
  }
}

class Particle {
  Offset position;
  Color color;
  double radius;
  double opacity;
  String direction;
  double speed;
  Particle(Random random, {this.direction = 'up'})
      : position = direction == 'up'
            ? Offset(random.nextDouble() * 300, 400)
            : Offset(random.nextDouble() * 300, 0),
        color = Color.fromARGB(
          255,
          random.nextInt(255),
          random.nextInt(255),
          random.nextInt(255),
        ),
        speed = 1.0,
        radius = 5 + random.nextDouble() * 10,
        opacity = 1.0;
}

class ParticlePainter extends CustomPainter {
  List<Particle> particles;
  AnimationController controller;

  ParticlePainter(this.particles, this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      var paint = Paint()..color = particle.color.withOpacity(particle.opacity);
      canvas.drawCircle(particle.position, particle.radius, paint);

      particle.position += particle.direction == 'up'
          ? Offset(0, -1 * particle.speed)
          : Offset(0, 1 * particle.speed);
      particle.opacity -= 0.0001; // Slower fade out
    }
    // Approximate Collision Logic
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        if ((particles[i].position - particles[j].position).distance < 30) {
          // Collision approximation

          // Updated color (interpolation)
          particles[i].color =
              Color.lerp(particles[i].color, particles[j].color, 0.5)!;

          // Optional - increase size slightly
          particles[i].radius += 2;
          particles[i].speed = 0;
          // Remove the other particle
          particles.removeAt(j);
        }
      }
    }
    // Remove faded particles
    particles.removeWhere((particle) => particle.opacity <= 0);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
// class _ParticleScreenState extends State<ParticleScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   List<Particle> _particles = [];

// //   @override
// //   void initState() {
// //     super.initState();
// //     _controller = AnimationController(
// //       duration: const Duration(seconds: 5),
// //       vsync: this,
// //     )..repeat();

// //     // Initial particle generation
// //     for (int i = 0; i < 20; i++) {
// //       _particles.add(Particle(_random));
// //     }
// //   }

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(seconds: 5),
//       vsync: this,
//     )..repeat();

//     _generateParticles(); // New function
//   }

//   void _generateParticles() {
//     Timer.periodic(Duration(milliseconds: 200), (_) {
//       // Generate new particles periodically
//       setState(() {
//         _particles.add(Particle(_random));
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   final Random _random = Random();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(color: Colors.blueGrey),
//         child: CustomPaint(
//           foregroundPainter: ParticlePainter(_particles, _controller),
//         ),
//       ),
//     );
//   }
// }

// class Particle {
//   Offset position;
//   Color color;
//   double radius;
//   double opacity;

//   Particle(Random random)
//       : position = Offset(random.nextDouble() * 300, 400),
//         color = Color.fromARGB(
//           255,
//           random.nextInt(255),
//           random.nextInt(255),
//           random.nextInt(255),
//         ),
//         radius = 5 + random.nextDouble() * 10,
//         opacity = 1.0;
// }

// class ParticlePainter extends CustomPainter {
//   List<Particle> particles;
//   AnimationController controller;

//   ParticlePainter(this.particles, this.controller) : super(repaint: controller);

//   @override
//   void paint(Canvas canvas, Size size) {
//     for (final particle in particles) {
//       var paint = Paint()..color = particle.color.withOpacity(particle.opacity);
//       canvas.drawCircle(particle.position, particle.radius, paint);

//       particle.position += Offset(0, -2); // Simple upward movement
//       particle.opacity -= 0.02; // Fade out
//     }

//     // Remove particles that have faded out
//     particles.removeWhere((particle) => particle.opacity <= 0);
//   }

//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) => true;
// }
