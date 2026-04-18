import 'dart:async';
import 'dart:typed_data';

import 'package:dart_chromaprint/dart_chromaprint.dart';
import 'package:file_picker/file_picker.dart';
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
  static const int _benchmarkIterations = 100;
  static const int _defaultPcmSampleRate = 44100;
  static const int _defaultPcmChannels = 2;

  final DartChromaprint _chromaprint = DartChromaprint();

  bool _isLoading = false;
  bool _isBenchmarking = false;
  String? _errorMessage;
  _SelectionResult? _result;
  BenchmarkSummary? _benchmarkSummary;

  Future<void> _pickPcmFile() async {
    await _pickAndFingerprintFile(isPcm: true);
  }

  Future<void> _pickWavFile() async {
    await _pickAndFingerprintFile(isPcm: false);
  }

  Future<void> _pickAndFingerprintFile({required bool isPcm}) async {
    final pickerResult = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: isPcm ? ['pcm'] : ['wav'],
      allowMultiple: false,
      withData: true,
    );

    if (pickerResult == null) {
      return;
    }

    final file = pickerResult.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'The selected file could not be loaded into memory.';
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isBenchmarking = false;
      _errorMessage = null;
      _result = null;
      _benchmarkSummary = null;
    });

    try {
      final result = isPcm
          ? _buildResultFromPcmBytes(fileName: file.name, bytes: bytes)
          : _buildResultFromWavBytes(fileName: file.name, bytes: bytes);

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
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

  _SelectionResult _buildResultFromPcmBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    final sampleRate = _defaultPcmSampleRate;
    final channels = _defaultPcmChannels;
    final samples = ChromaprintPreprocessor.decodeLittleEndianPcm(bytes);
    final fingerprintWords = _chromaprint.fingerprintWordsFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
    final fingerprint = _chromaprint.fingerprintStringFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );

    return _SelectionResult(
      fileName: fileName,
      formatLabel: 'PCM',
      sampleRate: sampleRate,
      channels: channels,
      frameCount: samples.length ~/ channels,
      fingerprintWords: fingerprintWords.length,
      fingerprint: fingerprint,
      samples: samples,
    );
  }

  _SelectionResult _buildResultFromWavBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    final wav = const ChromaprintWavReader().parseBytes(bytes);
    final fingerprintWords = _chromaprint.fingerprintWordsFromWavBytes(bytes);
    final fingerprint = _chromaprint.fingerprintStringFromWavBytes(bytes);

    return _SelectionResult(
      fileName: fileName,
      formatLabel: 'WAV',
      sampleRate: wav.sampleRate,
      channels: wav.channels,
      frameCount: wav.samples.length ~/ wav.channels,
      fingerprintWords: fingerprintWords.length,
      fingerprint: fingerprint,
      samples: wav.samples,
    );
  }

  Future<void> _runBenchmark() async {
    final result = _result;
    if (result == null) {
      return;
    }

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
            samples: result.samples,
            sampleRate: result.sampleRate,
            channels: result.channels,
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
          matchesBaseline: timedResult.lastValue == result.fingerprint,
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
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      title: 'Dart Chromaprint',
                      subtitle:
                          'Pick a PCM or WAV file and calculate a fingerprint entirely in Dart.',
                      accent: scheme.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WAV files are decoded with their embedded metadata. Raw PCM files use the app defaults for sample rate and channels.',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _isLoading ? null : _pickPcmFile,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.audio_file),
                                label: const Text('Choose PCM file'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _pickWavFile,
                                icon: const Icon(Icons.graphic_eq),
                                label: const Text('Choose WAV file'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _isLoading ||
                                        _isBenchmarking ||
                                        result == null
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
                        title: 'Fingerprint',
                        trailing: _SectionChip(label: result.formatLabel),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MetricRow(label: 'File', value: result.fileName),
                            _MetricRow(
                              label: 'Frames',
                              value: '${result.frameCount}',
                            ),
                            _MetricRow(
                              label: 'Fingerprint words',
                              value: '${result.fingerprintWords}',
                            ),
                            const SizedBox(height: 12),
                            _FingerprintField(
                              label: 'Fingerprint string',
                              value: result.fingerprint,
                            ),
                          ],
                        ),
                      ),
                      if (_benchmarkSummary != null) ...[
                        const SizedBox(height: 20),
                        _InfoCard(
                          title: '100x Benchmark',
                          trailing: _SectionChip(
                            label: _benchmarkSummary!.matchesBaseline
                                ? 'Matches'
                                : 'Mismatch',
                            isPositive: _benchmarkSummary!.matchesBaseline,
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
                    ] else
                      _InfoCard(
                        title: 'Ready',
                        child: Text(
                          'Choose a PCM or WAV file to calculate its fingerprint.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
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

class _SelectionResult {
  const _SelectionResult({
    required this.fileName,
    required this.formatLabel,
    required this.sampleRate,
    required this.channels,
    required this.frameCount,
    required this.fingerprintWords,
    required this.fingerprint,
    required this.samples,
  });

  final String fileName;
  final String formatLabel;
  final int sampleRate;
  final int channels;
  final int frameCount;
  final int fingerprintWords;
  final String fingerprint;
  final Int16List samples;
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

  final _SelectionResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'File',
            value: result.fileName,
            icon: Icons.insert_drive_file,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Format',
            value: result.formatLabel,
            icon: Icons.description,
          ),
        ),
        const SizedBox(width: 12),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              overflow: TextOverflow.ellipsis,
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

class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.label, this.isPositive = true});

  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isPositive
        ? const Color(0xFFE8F6F1)
        : scheme.errorContainer;
    final foreground = isPositive
        ? const Color(0xFF0F766E)
        : scheme.onErrorContainer;

    return Chip(
      label: Text(label),
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
