import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.ensemble import RandomForestClassifier

print("=== PHASE 1: NUMERICAL TRIAGE ENGINE STARTED ===")

# =====================================================================
# 1. DATA LOADING & TARGET HARMONIZATION
# =====================================================================
# Load our 18,000-row synthetic dataset
df = pd.read_csv('synthetic_medical_triage.csv')

# Clinical Mapping Strategy:
# Original level 3 -> Emergency (2)
# Original level 1 & 2 -> Urgent (1)
# Original level 0 -> Normal (0)
def map_target(level):
    if level == 3: 
        return 2    # Emergency
    elif level in [1, 2]: 
        return 1  # Urgent
    else: 
        return 0             # Normal

df['target_triage'] = df['triage_level'].apply(map_target)

# =====================================================================
# 2. FEATURE ENGINEERING & EXTRACTION
# =====================================================================
# Academic Custom Feature: Medical Shock Index calculation
# Formula: Shock Index = Heart Rate / Systolic Blood Pressure
df['shock_index'] = df['heart_rate'] / df['systolic_blood_pressure']

# Explicitly isolate features (inputs) and the target variable (output)
feature_cols = [
    'age', 'heart_rate', 'systolic_blood_pressure', 
    'oxygen_saturation', 'body_temperature', 'pain_level', 
    'chronic_disease_count', 'previous_er_visits', 'shock_index'
]

X = df[feature_cols]
y = df['target_triage']

# =====================================================================
# 3. TRAIN-TEST SPLIT (80% / 20%)
# =====================================================================
# Stratify ensures the percentage of classes matches perfectly across sets
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# =====================================================================
# 4. DATA SCALING (Standardization)
# =====================================================================
# Scaling features prevents variables with large numbers (like blood pressure)
# from dominating variables with tiny variations (like body temperature).
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# =====================================================================
# 5. MODEL TRAINING (Random Forest Baseline Classifier)
# =====================================================================
# Using Random Forest for high stability and multi-class target handling
print("Training the baseline machine learning classifier...")
model = RandomForestClassifier(n_estimators=100, random_state=42, class_weight='balanced')
model.fit(X_train_scaled, y_train)

# =====================================================================
# 6. SYSTEM EVALUATION
# =====================================================================
y_pred = model.predict(X_test_scaled)
y_proba = model.predict_proba(X_test_scaled)

print("\n--- PERFORMANCE METRICS ---")
print(f"Overall Model Classification Accuracy: {accuracy_score(y_test, y_pred) * 100:.2f}%")
print("\nDetailed Clinical Performance Report:")
print(classification_report(y_test, y_pred, target_names=['Normal', 'Urgent', 'Emergency']))

print("\nConfusion Matrix Output Matrix:")
print(confusion_matrix(y_test, y_pred))

# =====================================================================
# 7. EXPORT MODEL ARTIFACTS FOR FLASK DEPLOYMENT
# =====================================================================
# Saving these objects allows us to run calculations on our server instantly
joblib.dump(model, 'phase1_triage_model.pkl')
joblib.dump(scaler, 'phase1_scaler.pkl')
print("\nArtifact structures saved successfully: 'phase1_triage_model.pkl' & 'phase1_scaler.pkl'")