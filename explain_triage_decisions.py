import joblib
import pandas as pd
import numpy as np

print("=== COGNITIVE EXPLANATION LABELS PROCESSING ===")

# Load our trained Phase 2 artifacts
model = joblib.load('phase2_multimodal_model.pkl')
scaler = joblib.load('phase2_scaler.pkl')
tfidf = joblib.load('phase2_tfidf.pkl')

# Reconstruct feature column labels exactly as they were joined
numerical_cols = ['Age', 'heart_rate', 'systolic_bp', 'temperature', 'o2_sat', 'shock_index']
text_features = [f"word_{i}" for i in range(100)]
all_features = numerical_cols + text_features

# Get feature importance scores from the Random Forest engine
importances = model.feature_importances_

# Map the scores back to actual word names from the text vectorizer
feature_words = tfidf.get_feature_names_out()

# Build a clean dictionary to rename dummy 'word_X' labels back to actual clinical vocabulary
feature_names_mapped = list(numerical_cols) + list(feature_words)

# Match features with their mathematical importance metrics
importance_df = pd.DataFrame({
    'Clinical_Feature': feature_names_mapped,
    'Importance_Weight': importances
}).sort_values(by='Importance_Weight', ascending=False)

print("\n=== TOP 10 CLINICAL DRIVERS FOR PATIENT TRIAGE CRITERIA ===")
print(importance_df.head(10).to_string(index=False))