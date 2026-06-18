import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score

print("=== PHASE 2: MULTIMODAL TEXT + VITALS ENGINE STARTED ===")

# =====================================================================
# 1. LOAD AND CLEAN REAL CLINICAL DATA
# =====================================================================
# The raw file uses semicolons as delimiters
df_real = pd.read_csv('data.csv', delimiter=';', encoding='cp1252')

# Clean columns by converting text strings like '??' and commas to float numbers
vitals_cols = {'HR': 'heart_rate', 'SBP': 'systolic_bp', 'BT': 'temperature', 'Saturation': 'o2_sat'}

for raw_col, clean_col in vitals_cols.items():
    df_real[raw_col] = df_real[raw_col].replace('??', np.nan)
    if df_real[raw_col].dtype == 'object':
        df_real[raw_col] = df_real[raw_col].str.replace(',', '.')
    df_real[clean_col] = pd.to_numeric(df_real[raw_col], errors='coerce')
    # Impute missing cells safely using the column median value
    df_real[clean_col] = df_real[clean_col].fillna(df_real[clean_col].median())

# Clean and ensure age is numeric
df_real['Age'] = pd.to_numeric(df_real['Age'], errors='coerce').fillna(df_real['Age'].median())

# Calculate custom clinical feature: Shock Index
df_real['shock_index'] = df_real['heart_rate'] / df_real['systolic_bp']

# Clean chief complaint column text data
df_real['Chief_complain'] = df_real['Chief_complain'].fillna('missing complaint').astype(str)

# =====================================================================
# 2. TARGET CLASS HARMONIZATION MAPPING
# =====================================================================
# Mapping KTAS 1-2 -> Emergency (2), KTAS 3-4 -> Urgent (1), KTAS 5 -> Normal (0)
def map_ktas(score):
    if score in [1, 2]: 
        return 2
    elif score in [3, 4]: 
        return 1
    else: 
        return 0

df_real['target_triage'] = df_real['KTAS_expert'].apply(map_ktas)

# =====================================================================
# 3. SPLIT DATA INTO TRAIN AND TEST BEFORE NLP VECTORIZATION
# =====================================================================
# Split first to prevent information leakage from test tokens into the training set
df_train, df_test = train_test_split(
    df_real, test_size=0.2, random_state=42, stratify=df_real['target_triage']
)

# =====================================================================
# 4. NATURAL LANGUAGE PROCESSING (TF-IDF Vectorization)
# =====================================================================
# Vectorize symptom texts into numerical columns (Top 100 most clinical terms)
tfidf = TfidfVectorizer(max_features=100, stop_words='english')

X_train_text = tfidf.fit_transform(df_train['Chief_complain']).toarray()
X_test_text = tfidf.transform(df_test['Chief_complain']).toarray()

# Convert text arrays to dataframes
text_cols = [f"word_{i}" for i in range(X_train_text.shape[1])]
df_train_text = pd.DataFrame(X_train_text, columns=text_cols, index=df_train.index)
df_test_text = pd.DataFrame(X_test_text, columns=text_cols, index=df_test.index)

# =====================================================================
# 5. SCALE NUMERICAL VITAL FEATURES
# =====================================================================
numerical_cols = ['Age', 'heart_rate', 'systolic_bp', 'temperature', 'o2_sat', 'shock_index']
scaler = StandardScaler()

X_train_num = scaler.fit_transform(df_train[numerical_cols])
X_test_num = scaler.transform(df_test[numerical_cols])

df_train_num = pd.DataFrame(X_train_num, columns=numerical_cols, index=df_train.index)
df_test_num = pd.DataFrame(X_test_num, columns=numerical_cols, index=df_test.index)

# =====================================================================
# 6. FEATURE FUSION (Merge Text and Vitals Matrices)
# =====================================================================
X_train_final = pd.concat([df_train_num, df_train_text], axis=1)
X_test_final = pd.concat([df_test_num, df_test_text], axis=1)

y_train = df_train['target_triage']
y_test = df_test['target_triage']

# =====================================================================
# 7. MODEL TRAINING (Optimized Multimodal Triage Classifier)
# =====================================================================
print("Training the hyperparameter-tuned multimodal text + numerical vital engine...")

# Applying regularization constraints to clear decision boundaries and boost consensus
model_multimodal = RandomForestClassifier(
    n_estimators=250,          # Increased from 100 to 250 to allow a deeper statistical consensus
    max_depth=10,              # Regularizes trees by cutting off deep, hyper-specific noise memorization
    min_samples_split=8,       # Forces internal nodes to generalize across clusters
    min_samples_leaf=4,        # Prevents single noisy outlier cases from skewing individual tree votes
    class_weight='balanced',   # Ensures minority Emergency cases retain equal priority weights
    random_state=42,
    n_jobs=-1                  # Uses all available CPU cores to speed up execution in your IDE
)

model_multimodal.fit(X_train_final, y_train)
# =====================================================================
# 8. PERFORMANCE REPORTING
# =====================================================================
y_pred = model_multimodal.predict(X_test_final)

print("\n--- PHASE 2 PERFORMANCE METRICS ---")
print(f"Multimodal Engine Evaluation Accuracy: {accuracy_score(y_test, y_pred) * 100:.2f}%")
print("\nDetailed Clinical Performance Report:")
print(classification_report(y_test, y_pred, target_names=['Normal', 'Urgent', 'Emergency']))

print("\nConfusion Matrix Output Matrix:")
print(confusion_matrix(y_test, y_pred))

# =====================================================================
# 9. EXPORT PRODUCTION ARTIFACTS
# =====================================================================
joblib.dump(model_multimodal, 'phase2_multimodal_model.pkl')
joblib.dump(scaler, 'phase2_scaler.pkl')
joblib.dump(tfidf, 'phase2_tfidf.pkl')
print("\nArtifact structures saved successfully: 'phase2_multimodal_model.pkl', 'phase2_scaler.pkl' & 'phase2_tfidf.pkl'")