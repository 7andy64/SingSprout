"""
Convert CREPE-tiny model to TFLite for on-device pitch detection.

CREPE-tiny is a lightweight pitch detection model (~2MB).
Original: https://github.com/marl/crepe

Usage:
    pip install tensorflow numpy
    python tools/prepare_crepe_tiny.py

Note: This generates an untrained model architecture skeleton.
For production, download pre-trained CREPE weights from GitHub releases
or train on a pitch detection dataset. YIN is the primary fallback.
"""
import tensorflow as tf
import numpy as np


def build_crepe_tiny():
    """Build CREPE-tiny architecture (simplified)."""
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

    model = tf.keras.Model(inputs, outputs, name='crepe_tiny')
    return model


def convert_to_tflite():
    """Convert model to TFLite with quantization."""
    model = build_crepe_tiny()

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    def representative_dataset():
        for _ in range(100):
            yield [np.random.randn(1, 1024).astype(np.float32)]

    converter.representative_dataset = representative_dataset
    converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()

    output_path = 'sing_sprout/assets/models/crepe_tiny.tflite'
    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    print(f"Saved TFLite model: {output_path} ({len(tflite_model)} bytes)")


if __name__ == '__main__':
    convert_to_tflite()