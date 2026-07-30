"""
Convert CREPE-tiny pitch detection model to TFLite for on-device inference.

CREPE-tiny is a lightweight pitch detector (~2MB TFLite).
Original: https://github.com/marl/crepe

Usage:
    # Option A: From pre-trained weights (recommended, needs crepe + tensorflow)
    pip install crepe tensorflow numpy
    python tools/prepare_crepe_tiny.py

    # Option B: Untrained skeleton (for testing the pipeline, no pip deps needed)
    python tools/prepare_crepe_tiny.py --skeleton

Output: sing_sprout/assets/models/crepe_tiny.tflite

Architecture:
  Input:  1024-sample audio frame (23ms @ 44100Hz)
  Output: 360 pitch activation bins (C1–C7, 20-cent resolution)
  Size:   ~2MB (float16 quantized)
"""

import argparse
import os
import sys

import numpy as np

OUTPUT_DIR = 'sing_sprout/assets/models'
OUTPUT_FILE = os.path.join(OUTPUT_DIR, 'crepe_tiny.tflite')


def build_crepe_tiny():
    """Build CREPE-tiny architecture (Keras functional API)."""
    import tensorflow as tf

    inputs = tf.keras.Input(shape=(1024,), name='audio_frame')
    x = tf.keras.layers.Reshape((1024, 1))(inputs)
    x = tf.keras.layers.Conv1D(16, 512, padding='same', activation='relu')(x)
    x = tf.keras.layers.MaxPooling1D(2)(x)
    x = tf.keras.layers.Conv1D(32, 256, padding='same', activation='relu')(x)
    x = tf.keras.layers.MaxPooling1D(2)(x)
    x = tf.keras.layers.Conv1D(48, 128, padding='same', activation='relu')(x)
    x = tf.keras.layers.MaxPooling1D(2)(x)
    x = tf.keras.layers.Flatten()(x)
    x = tf.keras.layers.Dense(128, activation='relu')(x)
    outputs = tf.keras.layers.Dense(360, activation='sigmoid')(x)
    return tf.keras.Model(inputs, outputs, name='crepe_tiny')


def convert_keras_to_tflite(model, output_path):
    """Convert a Keras model to float16-quantized TFLite."""
    import tensorflow as tf

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]

    def representative_dataset():
        for _ in range(100):
            yield [np.random.randn(1, 1024).astype(np.float32)]

    converter.representative_dataset = representative_dataset

    tflite_model = converter.convert()
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    print(f'Saved: {output_path} ({len(tflite_model):,} bytes)')


def from_pretrained_crepe(output_path):
    """
    Extract pre-trained weights from the crepe PyPI package and convert to TFLite.

    The crepe package ships capacity='tiny' weights. We build the matching
    Keras architecture, load those weights, then convert.
    """
    import tensorflow as tf

    try:
        import crepe
    except ImportError:
        print('ERROR: crepe not installed. Run: pip install crepe tensorflow')
        print('Falling back to --skeleton mode.')
        return False

    # Load weights via crepe's internal loader
    try:
        model_cap = crepe.core.build_and_load_model(capacity='tiny')
        print(f'Loaded pre-trained CREPE-tiny from crepe v{crepe.__version__}')
    except Exception as e:
        print(f'ERROR loading crepe pre-trained model: {e}')
        print('Falling back to --skeleton mode.')
        return False

    convert_keras_to_tflite(model_cap, output_path)
    return True


def from_skeleton(output_path):
    """Build untrained architecture and convert (for pipeline testing only)."""
    model = build_crepe_tiny()
    model.summary()
    print('\nWARNING: This model has RANDOM weights and will not detect pitch correctly.')
    print('For production, install crepe + tensorflow and re-run without --skeleton.')
    convert_keras_to_tflite(model, output_path)


def main():
    parser = argparse.ArgumentParser(description='Prepare CREPE-tiny TFLite model')
    parser.add_argument(
        '--skeleton', action='store_true',
        help='Generate untrained architecture skeleton (for testing only)',
    )
    parser.add_argument(
        '-o', '--output', default=OUTPUT_FILE,
        help=f'Output path (default: {OUTPUT_FILE})',
    )
    args = parser.parse_args()

    if args.skeleton:
        from_skeleton(args.output)
        return

    # Try pre-trained first
    print('Attempting to convert pre-trained CREPE-tiny weights...')
    print('(pip install crepe tensorflow if this fails)\n')

    if not from_pretrained_crepe(args.output):
        from_skeleton(args.output)
        sys.exit(1)


if __name__ == '__main__':
    main()
