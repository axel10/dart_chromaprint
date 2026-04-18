import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_chromaprint/dart_chromaprint.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dart Chromaprint Demo',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF3F7F6),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  static const int _sampleRate = 11025;
  static const int _channels = 2;
  static const Duration _duration = Duration(seconds: 3);
  static const int _benchmarkIterations = 100;

  final DartChromaprint _chromaprint = DartChromaprint();

  bool _isLoading = true;
  bool _isBenchmarking = false;
  String? _errorMessage;
  _DemoFingerprint? _result;
  BenchmarkSummary? _benchmarkSummary;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  Future<void> _recompute() async {
    setState(() {
      _isLoading = true;
      _isBenchmarking = false;
      _errorMessage = null;
      _result = null;
      _benchmarkSummary = null;
    });

    try {
      final demo = _buildDemoAudio(
        sampleRate: _sampleRate,
        channels: _channels,
        duration: _duration,
      );

      final pcmFingerprint = _chromaprint.fingerprintStringFromInt16Pcm(
        samples: demo.samples,
        sampleRate: _sampleRate,
        channels: _channels,
      );
      final wavFingerprint = _chromaprint.fingerprintStringFromWavBytes(
        demo.wavBytes,
      );
      final fingerprintWords = _chromaprint.fingerprintWordsFromInt16Pcm(
        samples: demo.samples,
        sampleRate: _sampleRate,
        channels: _channels,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = _DemoFingerprint(
          sampleRate: _sampleRate,
          channels: _channels,
          duration: _duration,
          sampleCount: demo.samples.length,
          fingerprintWords: fingerprintWords.length,
          pcmFingerprint: pcmFingerprint,
          wavFingerprint: wavFingerprint,
        );
        _benchmarkSummary = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runBenchmark() async {
    final result = _result;
    if (result == null) {
      return;
    }

    final demo = _buildDemoAudio(
      sampleRate: _sampleRate,
      channels: _channels,
      duration: _duration,
    );

    setState(() {
      _isBenchmarking = true;
      _errorMessage = null;
      _benchmarkSummary = null;
    });

    try {
      final timedResult = await _benchmark<String>(
        iterations: _benchmarkIterations,
        body: () {
          return _chromaprint.fingerprintStringFromInt16Pcm(
            samples: demo.samples,
            sampleRate: _sampleRate,
            channels: _channels,
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _benchmarkSummary = BenchmarkSummary(
          iterations: _benchmarkIterations,
          total: timedResult.total,
          averageMicros: timedResult.averageMicros,
          lastValue: timedResult.lastValue,
          matchesBaseline: timedResult.lastValue == result.pcmFingerprint,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBenchmarking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = _result;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.10),
              const Color(0xFFF3F7F6),
              scheme.secondary.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      title: 'Dart Chromaprint',
                      subtitle:
                          'Pure Dart PCM and WAV fingerprinting, no Rust bridge required.',
                      accent: scheme.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This demo synthesizes a short stereo signal in memory, calculates the fingerprint from raw PCM, then wraps the same samples as a WAV buffer and checks that both outputs match.',
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _isLoading ? null : _recompute,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.fingerprint),
                                label: Text(
                                  _isLoading ? 'Calculating...' : 'Recompute',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _recompute,
                                icon: const Icon(Icons.restart_alt),
                                label: const Text('Run again'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isLoading || _isBenchmarking
                                    ? null
                                    : _runBenchmark,
                                icon: _isBenchmarking
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.speed),
                                label: Text(
                                  _isBenchmarking
                                      ? 'Benchmarking...'
                                      : 'Run 100x Benchmark',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      _InfoCard(
                        title: 'Error',
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      )
                    else if (_isLoading)
                      const _InfoCard(
                        title: 'Working',
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (result != null) ...[
                      _StatsGrid(result: result),
                      const SizedBox(height: 20),
                      _InfoCard(
                        title: 'Fingerprints',
                        trailing: _MatchChip(matches: result.matches),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FingerprintField(
                              label: 'From PCM',
                              value: result.pcmFingerprint,
                            ),
                            const SizedBox(height: 16),
                            _FingerprintField(
                              label: 'From WAV bytes',
                              value: result.wavFingerprint,
                            ),
                          ],
                        ),
                      ),
                      if (_benchmarkSummary != null) ...[
                        const SizedBox(height: 20),
                        _InfoCard(
                          title: '100x Benchmark',
                          trailing: _MatchChip(
                            matches: _benchmarkSummary!.matchesBaseline,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MetricRow(
                                label: 'Iterations',
                                value: '${_benchmarkSummary!.iterations}',
                              ),
                              _MetricRow(
                                label: 'Total',
                                value: _formatDuration(
                                  _benchmarkSummary!.total,
                                ),
                              ),
                              _MetricRow(
                                label: 'Average',
                                value: _formatMicros(
                                  _benchmarkSummary!.averageMicros,
                                ),
                              ),
                              _MetricRow(
                                label: 'Output matches current result',
                                value: _benchmarkSummary!.matchesBaseline
                                    ? 'Yes'
                                    : 'No',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoFingerprint {
  const _DemoFingerprint({
    required this.sampleRate,
    required this.channels,
    required this.duration,
    required this.sampleCount,
    required this.fingerprintWords,
    required this.pcmFingerprint,
    required this.wavFingerprint,
  });

  final int sampleRate;
  final int channels;
  final Duration duration;
  final int sampleCount;
  final int fingerprintWords;
  final String pcmFingerprint;
  final String wavFingerprint;

  bool get matches => pcmFingerprint == wavFingerprint;
}

class _DemoAudio {
  const _DemoAudio({required this.samples, required this.wavBytes});

  final Int16List samples;
  final Uint8List wavBytes;
}

class BenchmarkSummary {
  const BenchmarkSummary({
    required this.iterations,
    required this.total,
    required this.averageMicros,
    required this.lastValue,
    required this.matchesBaseline,
  });

  final int iterations;
  final Duration total;
  final double averageMicros;
  final String lastValue;
  final bool matchesBaseline;
}

class _TimedResult<T> {
  const _TimedResult({
    required this.total,
    required this.averageMicros,
    required this.lastValue,
  });

  final Duration total;
  final double averageMicros;
  final T lastValue;
}

Future<_TimedResult<T>> _benchmark<T>({
  required int iterations,
  required FutureOr<T> Function() body,
}) async {
  T lastValue = await body();
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    lastValue = await body();
  }
  stopwatch.stop();

  final total = stopwatch.elapsed;
  return _TimedResult(
    total: total,
    averageMicros: total.inMicroseconds / iterations,
    lastValue: lastValue,
  );
}

_DemoAudio _buildDemoAudio({
  required int sampleRate,
  required int channels,
  required Duration duration,
}) {
  final frameCount = sampleRate * duration.inSeconds;
  final samples = Int16List(frameCount * channels);
  const amplitude = 0.65;

  for (var frame = 0; frame < frameCount; frame++) {
    final t = frame / sampleRate;
    final left = math.sin(2.0 * math.pi * 220.0 * t);
    final right = math.sin(2.0 * math.pi * 330.0 * t);
    final leftSample = (left * amplitude * 32767.0).round().clamp(
      -32768,
      32767,
    );
    final rightSample = (right * amplitude * 32767.0).round().clamp(
      -32768,
      32767,
    );

    final offset = frame * channels;
    samples[offset] = leftSample;
    if (channels > 1) {
      samples[offset + 1] = rightSample;
    }
    for (var channel = 2; channel < channels; channel++) {
      samples[offset + channel] = leftSample;
    }
  }

  return _DemoAudio(
    samples: samples,
    wavBytes: _buildPcm16WavBytes(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    ),
  );
}

Uint8List _buildPcm16WavBytes({
  required Int16List samples,
  required int sampleRate,
  required int channels,
}) {
  const bitsPerSample = 16;
  final dataBytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    dataBytes.setInt16(i * 2, samples[i], Endian.little);
  }

  final bytesPerSample = bitsPerSample ~/ 8;
  final byteRate = sampleRate * channels * bytesPerSample;
  final blockAlign = channels * bytesPerSample;
  final dataSize = dataBytes.lengthInBytes;
  final fileSize = 36 + dataSize;

  final output = BytesBuilder(copy: false)
    ..add('RIFF'.codeUnits)
    ..add(_uint32le(fileSize))
    ..add('WAVE'.codeUnits)
    ..add('fmt '.codeUnits)
    ..add(_uint32le(16))
    ..add(_uint16le(1))
    ..add(_uint16le(channels))
    ..add(_uint32le(sampleRate))
    ..add(_uint32le(byteRate))
    ..add(_uint16le(blockAlign))
    ..add(_uint16le(bitsPerSample))
    ..add('data'.codeUnits)
    ..add(_uint32le(dataSize))
    ..add(dataBytes.buffer.asUint8List());

  return output.takeBytes();
}

Uint8List _uint16le(int value) {
  final data = ByteData(2)..setUint16(0, value, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List _uint32le(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.little);
  return data.buffer.asUint8List();
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.95),
            accent.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) ...[trailing!],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.result});

  final _DemoFingerprint result;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Sample rate',
            value: '${result.sampleRate} Hz',
            icon: Icons.graphic_eq,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Channels',
            value: '${result.channels}',
            icon: Icons.audiotrack,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Frames',
            value: _formatDuration(result.duration),
            icon: Icons.timelapse,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Words',
            value: '${result.fingerprintWords}',
            icon: Icons.memory,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 14),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerprintField extends StatelessWidget {
  const _FingerprintField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 88, maxHeight: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8E3E1)),
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SelectableText(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.matches});

  final bool matches;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = matches
        ? const Color(0xFFE8F6F1)
        : scheme.errorContainer;
    final foreground = matches
        ? const Color(0xFF0F766E)
        : scheme.onErrorContainer;

    return Chip(
      label: Text(matches ? 'PCM and WAV match' : 'Mismatch'),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      backgroundColor: background,
      side: BorderSide(color: foreground.withValues(alpha: 0.25)),
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration.inMilliseconds >= 1000) {
    return '${(duration.inMilliseconds / 1000.0).toStringAsFixed(2)} s';
  }
  return '${duration.inMilliseconds} ms';
}

String _formatMicros(double micros) {
  if (micros >= 1000.0) {
    return '${(micros / 1000.0).toStringAsFixed(2)} ms';
  }
  return '${micros.toStringAsFixed(1)} us';
}
