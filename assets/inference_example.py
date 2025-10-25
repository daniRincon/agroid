
# Ejemplo de uso del modelo MobileFaceNet TFLite
import tensorflow as tf
import numpy as np
import cv2

def extract_face_embedding(image_path, model_path):
    """
    Extrae el embedding facial de una imagen usando MobileFaceNet TFLite
    
    Args:
        image_path: Ruta a la imagen de entrada
        model_path: Ruta al modelo TFLite
    
    Returns:
        embedding: Vector de características faciales normalizado
    """
    # Cargar modelo
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Cargar y preprocesar imagen
    img = cv2.imread(image_path)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img = cv2.resize(img, (112, 112))  # Redimensionar a 112x112
    img = img.astype(np.float32)
    img = (img - 127.5) / 128.0  # Normalizar a [-1, 1]
    img = np.expand_dims(img, axis=0)  # Añadir dimensión de batch
    
    # Realizar inferencia
    interpreter.set_tensor(input_details[0]['index'], img)
    interpreter.invoke()
    embedding = interpreter.get_tensor(output_details[0]['index'])
    
    return embedding[0]  # Retornar primer (y único) embedding

def calculate_similarity(embedding1, embedding2):
    """
    Calcula la similitud coseno entre dos embeddings
    
    Returns:
        similarity: Valor entre -1 y 1 (1 = idénticos, 0 = ortogonales, -1 = opuestos)
    """
    dot_product = np.dot(embedding1, embedding2)
    norm1 = np.linalg.norm(embedding1)
    norm2 = np.linalg.norm(embedding2)
    similarity = dot_product / (norm1 * norm2)
    return similarity

# Ejemplo de uso:
# embedding1 = extract_face_embedding("foto1.jpg", "mobilefacenet.tflite")
# embedding2 = extract_face_embedding("foto2.jpg", "mobilefacenet.tflite")
# similarity = calculate_similarity(embedding1, embedding2)
# print(f"Similitud: {similarity:.4f}")
# 
# # Umbral típico para reconocimiento facial: 0.5-0.7
# if similarity > 0.6:
#     print("¡Las caras son de la misma persona!")
# else:
#     print("Las caras son de personas diferentes.")
