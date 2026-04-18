import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_chromaprint/dart_chromaprint.dart';
import 'package:dart_chromaprint/chromaprint_api.dart' as internal_api;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dart Chromaprint Demo',
      theme: ThemeData(
        colorScheme: scheme,
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
  static const int _pcmSampleRate = 44100;
  static const int _pcmChannels = 2;

  final TextEditingController _sampleRateController = TextEditingController(
    text: '44100',
  );
  final TextEditingController _channelsController = TextEditingController(
    text: '2',
  );
  final TextEditingController _benchmarkIterationsController =
      TextEditingController(text: '30');

  bool _loading = false;
  bool _benchmarking = false;
  _BenchmarkExecutionMode _benchmarkExecutionMode =
      _BenchmarkExecutionMode.isolate;
  String? _error;
  String? _title;
  String? _fingerprint;
  _InputKind? _selectedKind;
  _PcmSelection? _pcmSelection;
  _WavSelection? _wavSelection;
  BenchmarkResult? _benchmarkResult;

  Future<void> _pickPcmFile() async {
    await _pickAndFingerprint(
      title: 'PCM fingerprint',
      kind: _InputKind.pcm,
      allowedExtensions: const ['pcm'],
      builder: (file) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw StateError('The selected PCM file could not be loaded.');
        }

        final sampleRate = _parseRequiredInt(
          controller: _sampleRateController,
          fieldName: '采样率',
        );
        final channels = _parseRequiredInt(
          controller: _channelsController,
          fieldName: '声道数',
        );

        final pcm = _decodeLittleEndianPcm(bytes);

        _pcmSelection = _PcmSelection(
          pcm: pcm,
          sampleRate: sampleRate,
          channels: channels,
        );

        return fingerprintFromPcm(
          pcm: pcm,
          sampleRate: sampleRate,
          channels: channels,
        );
      },
    );
  }

  Future<void> _pickWavFile() async {
    await _pickAndFingerprint(
      title: 'WAV fingerprint',
      kind: _InputKind.wav,
      allowedExtensions: const ['wav'],
      builder: (file) {
        final path = file.path;
        if (path == null || path.isEmpty) {
          throw StateError('This platform did not provide a WAV file path.');
        }

        _wavSelection = _WavSelection(path: path);
        return fingerprintFromWavFile(path);
      },
    );
  }

  @override
  void dispose() {
    _sampleRateController.dispose();
    _channelsController.dispose();
    _benchmarkIterationsController.dispose();
    super.dispose();
  }

  Future<void> _pickAndFingerprint({
    required String title,
    required _InputKind kind,
    required List<String> allowedExtensions,
    required FutureOr<String> Function(PlatformFile file) builder,
  }) async {
    final pickerResult = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: true,
    );

    if (pickerResult == null) {
      return;
    }

    final file = pickerResult.files.single;

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _benchmarking = false;
      _error = null;
      _title = null;
      _fingerprint = null;
      _selectedKind = kind;
      _benchmarkResult = null;
      if (kind == _InputKind.pcm) {
        _wavSelection = null;
      } else {
        _pcmSelection = null;
      }
    });

    try {
      final fingerprint = await builder(file);
      if (!mounted) {
        return;
      }

      setState(() {
        _title = title;
        _fingerprint = fingerprint;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _runBenchmark() async {
    final kind = _selectedKind;
    if (kind == null || _loading || _benchmarking) {
      return;
    }

    setState(() {
      _benchmarking = true;
      _error = null;
      _benchmarkResult = null;
    });

    try {
      late final BenchmarkResult result;
      final iterations = _parseRequiredInt(
        controller: _benchmarkIterationsController,
        fieldName: 'benchmark iterations',
      );
      if (kind == _InputKind.pcm) {
        final selection = _pcmSelection;
        if (selection == null) {
          throw StateError('Pick a PCM file first.');
        }
        final rawResult = switch (_benchmarkExecutionMode) {
          _BenchmarkExecutionMode.mainThread => _benchmarkPcm(
              pcm: selection.pcm,
              sampleRate: selection.sampleRate,
              channels: selection.channels,
              iterations: iterations,
              executionLabel: 'Main thread',
            ),
          _BenchmarkExecutionMode.isolate => await _runPcmBenchmarkInIsolate(
              pcm: selection.pcm,
              sampleRate: selection.sampleRate,
              channels: selection.channels,
              iterations: iterations,
            ),
        };
        result = _benchmarkResultFromMap(rawResult);
      } else {
        final selection = _wavSelection;
        if (selection == null) {
          throw StateError('Pick a WAV file first.');
        }
        final rawResult = switch (_benchmarkExecutionMode) {
          _BenchmarkExecutionMode.mainThread => _benchmarkWav(
              path: selection.path,
              iterations: iterations,
              executionLabel: 'Main thread',
            ),
          _BenchmarkExecutionMode.isolate => await _runWavBenchmarkInIsolate(
              path: selection.path,
              iterations: iterations,
            ),
        };
        result = _benchmarkResultFromMap(rawResult);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _benchmarkResult = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _benchmarking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              const Color(0xFFF3F7F6),
              scheme.secondary.withValues(alpha: 0.10),
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
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      accent: scheme.primary,
                      title: 'Dart Chromaprint',
                      subtitle:
                          'Only two public APIs: fingerprintFromPcm and fingerprintFromWavFile.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PCM data must provide the sample rate and channel count. Default values are $_pcmChannels channels and $_pcmSampleRate Hz.',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _NumberField(
                                  controller: _channelsController,
                                  label: 'PCM channels',
                                  hintText: '2',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _NumberField(
                                  controller: _sampleRateController,
                                  label: 'PCM sample rate',
                                  hintText: '44100',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _NumberField(
                                  controller: _benchmarkIterationsController,
                                  label: 'Benchmark iterations',
                                  hintText: '30',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _BenchmarkModeSelector(
                            value: _benchmarkExecutionMode,
                            onChanged: (mode) {
                              setState(() {
                                _benchmarkExecutionMode = mode;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _loading ? null : _pickPcmFile,
                                icon: const Icon(Icons.audio_file),
                                label: const Text('Choose PCM file'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _loading ? null : _pickWavFile,
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
                                    _loading ||
                                        _benchmarking ||
                                        _selectedKind == null
                                    ? null
                                    : _runBenchmark,
                                icon: _benchmarking
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.speed),
                                label: Text(
                                  _benchmarking
                                      ? 'Benchmarking'
                                      : 'Run benchmark',
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
                    if (_loading)
                      const _InfoCard(
                        title: 'Working',
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_error != null)
                      _InfoCard(
                        title: 'Error',
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                    if (_fingerprint != null)
                      _InfoCard(
                        title: _title ?? 'Fingerprint',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MetricRow(
                              label: 'Sample rate',
                              value: '$_pcmSampleRate Hz',
                            ),
                            _MetricRow(
                              label: 'Channels',
                              value: '$_pcmChannels',
                            ),
                            const SizedBox(height: 12),
                            _FingerprintField(value: _fingerprint!),
                          ],
                        ),
                      ),
                    if (_benchmarkResult != null) ...[
                      const SizedBox(height: 20),
                      _InfoCard(
                        title:
                            '${_benchmarkResult!.iterations}x Benchmark',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MetricRow(
                              label: 'Input',
                              value: _benchmarkResult!.inputLabel,
                            ),
                            _MetricRow(
                              label: 'Execution',
                              value: _benchmarkResult!.executionLabel,
                            ),
                            _MetricRow(
                              label: 'Iterations',
                              value: '${_benchmarkResult!.iterations}',
                            ),
                            _MetricRow(
                              label: 'Total',
                              value: _formatDuration(_benchmarkResult!.total),
                            ),
                            _MetricRow(
                              label: 'Average',
                              value: _formatMicros(
                                _benchmarkResult!.averageMicros,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FingerprintField(
                              value: _benchmarkResult!.fingerprint,
                            ),
                          ],
                        ),
                      ),
                    ] else if (_fingerprint == null)
                      _InfoCard(
                        title: 'Ready',
                        child: Text(
                          'Pick a PCM file or a WAV file to calculate its fingerprint. You can then run the benchmark on the selected input using the chosen execution mode.',
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

Int16List _decodeLittleEndianPcm(Uint8List bytes) {
  if (bytes.lengthInBytes.isOdd) {
    throw ArgumentError('PCM byte length must be even.');
  }

  final sampleCount = bytes.lengthInBytes ~/ 2;
  final samples = Int16List(sampleCount);
  final data = ByteData.sublistView(bytes);

  for (var i = 0; i < sampleCount; i++) {
    samples[i] = data.getInt16(i * 2, Endian.little);
  }

  return samples;
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
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _BenchmarkModeSelector extends StatelessWidget {
  const _BenchmarkModeSelector({
    required this.value,
    required this.onChanged,
  });

  final _BenchmarkExecutionMode value;
  final ValueChanged<_BenchmarkExecutionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Benchmark execution',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ToggleButtons(
          isSelected: [
            value == _BenchmarkExecutionMode.mainThread,
            value == _BenchmarkExecutionMode.isolate,
          ],
          onPressed: (index) {
            onChanged(
              index == 0
                  ? _BenchmarkExecutionMode.mainThread
                  : _BenchmarkExecutionMode.isolate,
            );
          },
          borderRadius: BorderRadius.circular(14),
          borderColor: Colors.white.withValues(alpha: 0.35),
          selectedBorderColor: Colors.white,
          fillColor: Colors.white,
          color: Colors.white,
          selectedColor: const Color(0xFF0F766E),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          constraints: const BoxConstraints(minHeight: 44),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Main thread'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Isolate'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value == _BenchmarkExecutionMode.mainThread
              ? 'Runs the benchmark directly on the UI isolate.'
              : 'Runs the benchmark inside a separate isolate.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}

class _FingerprintField extends StatelessWidget {
  const _FingerprintField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E3E1)),
      ),
      child: SelectableText(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.5,
        ),
      ),
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

class BenchmarkResult {
  const BenchmarkResult({
    required this.inputLabel,
    required this.executionLabel,
    required this.iterations,
    required this.total,
    required this.averageMicros,
    required this.fingerprint,
  });

  final String inputLabel;
  final String executionLabel;
  final int iterations;
  final Duration total;
  final double averageMicros;
  final String fingerprint;
}

class _PcmSelection {
  const _PcmSelection({
    required this.pcm,
    required this.sampleRate,
    required this.channels,
  });

  final Int16List pcm;
  final int sampleRate;
  final int channels;
}

class _WavSelection {
  const _WavSelection({required this.path});

  final String path;
}

enum _InputKind { pcm, wav }

enum _BenchmarkExecutionMode { mainThread, isolate }

Future<Map<String, Object>> _runPcmBenchmarkInIsolate({
  required Int16List pcm,
  required int sampleRate,
  required int channels,
  required int iterations,
}) {
  // Keep the isolate launch outside the widget State so the closure does not
  // accidentally capture Flutter objects such as the binding or context.
  return Isolate.run(
    () => _benchmarkPcm(
      pcm: pcm,
      sampleRate: sampleRate,
      channels: channels,
      iterations: iterations,
      executionLabel: 'Isolate',
    ),
  );
}

Future<Map<String, Object>> _runWavBenchmarkInIsolate({
  required String path,
  required int iterations,
}) {
  // Same idea as the PCM path: only send plain data into the isolate.
  return Isolate.run(
    () => _benchmarkWav(
      path: path,
      iterations: iterations,
      executionLabel: 'Isolate',
    ),
  );
}

Map<String, Object> _benchmarkPcm({
  required Int16List pcm,
  required int sampleRate,
  required int channels,
  required int iterations,
  required String executionLabel,
}) {
  final stopwatch = Stopwatch()..start();
  String lastFingerprint = '';
  for (var i = 0; i < iterations; i++) {
    lastFingerprint = fingerprintFromPcm(
      pcm: pcm,
      sampleRate: sampleRate,
      channels: channels,
    );
  }
  stopwatch.stop();

  return <String, Object>{
    'inputLabel': 'PCM',
    'executionLabel': executionLabel,
    'iterations': iterations,
    'totalMicros': stopwatch.elapsed.inMicroseconds,
    'averageMicros': stopwatch.elapsed.inMicroseconds / iterations,
    'fingerprint': lastFingerprint,
  };
}

Map<String, Object> _benchmarkWav({
  required String path,
  required int iterations,
  required String executionLabel,
}) {
  final pipeline = internal_api.ChromaprintPipeline();
  final stopwatch = Stopwatch()..start();
  String lastFingerprint = '';
  for (var i = 0; i < iterations; i++) {
    final bytes = File(path).readAsBytesSync();
    lastFingerprint = pipeline.fingerprintStringFromWavBytes(bytes);
  }
  stopwatch.stop();

  return <String, Object>{
    'inputLabel': 'WAV',
    'executionLabel': executionLabel,
    'iterations': iterations,
    'totalMicros': stopwatch.elapsed.inMicroseconds,
    'averageMicros': stopwatch.elapsed.inMicroseconds / iterations,
    'fingerprint': lastFingerprint,
  };
}

BenchmarkResult _benchmarkResultFromMap(Map<String, Object> raw) {
  return BenchmarkResult(
    inputLabel: raw['inputLabel'] as String,
    executionLabel: raw['executionLabel'] as String,
    iterations: raw['iterations'] as int,
    total: Duration(microseconds: raw['totalMicros'] as int),
    averageMicros: raw['averageMicros'] as double,
    fingerprint: raw['fingerprint'] as String,
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.hintText,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.14),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white, width: 1.4),
        ),
      ),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    );
  }
}

int _parseRequiredInt({
  required TextEditingController controller,
  required String fieldName,
}) {
  final value = int.tryParse(controller.text.trim());
  if (value == null || value <= 0) {
    throw ArgumentError('$fieldName must be a positive integer.');
  }
  return value;
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
