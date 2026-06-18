import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import StandardScaler, label_binarize
from sklearn.metrics import (
    classification_report, confusion_matrix, accuracy_score, roc_auc_score
)
from xgboost import XGBClassifier

print("=" * 65)
print("  PHASE 3: XGBOOST MULTIMODAL TRIAGE ENGINE — UPGRADED")
print("=" * 65)

# =====================================================================
# 1. LOAD AND CLEAN REAL CLINICAL DATA (same source as Phase 2)
# =====================================================================
print("\n[1/9] Loading and cleaning clinical dataset...")

df_real = pd.read_csv('data.csv', delimiter=';', encoding='cp1252')

# Clean vitals columns — handle '??' nulls and European comma decimals
vitals_cols = {'HR': 'heart_rate', 'SBP': 'systolic_bp', 'BT': 'temperature', 'Saturation': 'o2_sat'}

for raw_col, clean_col in vitals_cols.items():
    df_real[raw_col] = df_real[raw_col].replace('??', np.nan)
    if df_real[raw_col].dtype == 'object':
        df_real[raw_col] = df_real[raw_col].str.replace(',', '.')
    df_real[clean_col] = pd.to_numeric(df_real[raw_col], errors='coerce')
    df_real[clean_col] = df_real[clean_col].fillna(df_real[clean_col].median())

df_real['Age'] = pd.to_numeric(df_real['Age'], errors='coerce').fillna(df_real['Age'].median())
df_real['Chief_complain'] = df_real['Chief_complain'].fillna('missing complaint').astype(str).str.lower()

# =====================================================================
# 2. ENHANCED CLINICAL FEATURE ENGINEERING (6 → 11 Features)
# =====================================================================
print("[2/9] Engineering 5 additional clinical composite features...")

# Original Phase 2 feature
df_real['shock_index'] = df_real['heart_rate'] / df_real['systolic_bp']

# ── NEW: 5 additional composite clinical indicators ──────────────────
# Pulse Pressure Proxy — approximates cardiovascular wall tension
df_real['pulse_pressure_proxy'] = df_real['systolic_bp'] * 0.4

# Binary clinical risk flags — hard clinical decision thresholds
df_real['hypoxia_flag']      = (df_real['o2_sat']      <= 94).astype(int)
df_real['tachycardia_flag']  = (df_real['heart_rate']  >  100).astype(int)
df_real['hypotension_flag']  = (df_real['systolic_bp'] <  90).astype(int)
df_real['age_risk_score']    = (df_real['Age']          >  65).astype(int)

# =====================================================================
# 3. TARGET CLASS HARMONIZATION (KTAS → 3-Class System)
# =====================================================================
print("[3/9] Mapping KTAS expert scores to 3-class triage labels...")

# KTAS 1-2 → Emergency (2) | KTAS 3-4 → Urgent (1) | KTAS 5 → Normal (0)
def map_ktas(score):
    if score in [1, 2]:   return 2   # Emergency
    elif score in [3, 4]: return 1   # Urgent
    else:                 return 0   # Normal

df_real['target_triage'] = df_real['KTAS_expert'].apply(map_ktas)

# =====================================================================
# 4. TRAIN / TEST SPLIT (before NLP to prevent data leakage)
# =====================================================================
print("[4/9] Splitting data 80/20 (stratified by triage class)...")

df_train, df_test = train_test_split(
    df_real, test_size=0.2, random_state=42, stratify=df_real['target_triage']
)

# =====================================================================
# 5. UPGRADED NLP — TF-IDF BIGRAMS (150 features, log dampening)
# =====================================================================
print("[5/9] Fitting upgraded TF-IDF vectorizer (bigrams, 150 features)...")

# ngram_range=(1,2) captures clinical phrases like "chest pain", "shortness breath"
# sublinear_tf=True applies log(tf+1) dampening — reduces noise from repeated terms
tfidf = TfidfVectorizer(
    max_features=150,
    ngram_range=(1, 2),        # Unigrams + bigrams
    stop_words='english',
    sublinear_tf=True          # Log dampening of term frequency
)

X_train_text = tfidf.fit_transform(df_train['Chief_complain']).toarray()
X_test_text  = tfidf.transform(df_test['Chief_complain']).toarray()

n_text_features = X_train_text.shape[1]
text_cols = [f"word_{i}" for i in range(n_text_features)]

df_train_text = pd.DataFrame(X_train_text, columns=text_cols, index=df_train.index)
df_test_text  = pd.DataFrame(X_test_text,  columns=text_cols, index=df_test.index)

# =====================================================================
# 6. SCALE ALL 11 NUMERICAL FEATURES
# =====================================================================
print("[6/9] Scaling 11-dimensional numerical vital feature matrix...")

NUMERICAL_COLS = [
    'Age', 'heart_rate', 'systolic_bp', 'temperature', 'o2_sat',
    'shock_index',
    'pulse_pressure_proxy', 'hypoxia_flag', 'tachycardia_flag',
    'hypotension_flag', 'age_risk_score'
]

scaler = StandardScaler()
X_train_num = scaler.fit_transform(df_train[NUMERICAL_COLS])
X_test_num  = scaler.transform(df_test[NUMERICAL_COLS])

df_train_num = pd.DataFrame(X_train_num, columns=NUMERICAL_COLS, index=df_train.index)
df_test_num  = pd.DataFrame(X_test_num,  columns=NUMERICAL_COLS, index=df_test.index)

# =====================================================================
# 7. MULTIMODAL FEATURE FUSION (11 Vitals + 150 NLP = 161 Features)
# =====================================================================
print("[7/9] Fusing vitals and NLP into unified 161-feature matrix...")

X_train_final = pd.concat([df_train_num, df_train_text], axis=1)
X_test_final  = pd.concat([df_test_num,  df_test_text],  axis=1)

y_train = df_train['target_triage']
y_test  = df_test['target_triage']

print(f"       Training matrix shape: {X_train_final.shape}")
print(f"       Test matrix shape:     {X_test_final.shape}")

# =====================================================================
# 8. XGBOOST MODEL TRAINING
# =====================================================================
print("\n[8/9] Training XGBoost multimodal classifier (this may take ~60s)...")

model_xgb = XGBClassifier(
    n_estimators=500,           # 500 sequential boosting rounds
    learning_rate=0.05,         # Slow learning rate → better generalization
    max_depth=6,                # Balanced tree depth
    subsample=0.8,              # Row subsampling → reduces overfitting
    colsample_bytree=0.8,       # Feature subsampling per tree
    min_child_weight=3,         # Minimum samples in leaf → prevents memorization
    gamma=0.1,                  # Minimum loss reduction to make a split
    reg_alpha=0.1,              # L1 regularization on leaf weights
    reg_lambda=1.5,             # L2 regularization (stronger penalty)
    objective='multi:softprob', # Probabilistic multiclass output
    num_class=3,
    eval_metric='mlogloss',
    use_label_encoder=False,
    random_state=42,
    n_jobs=-1                   # Use all CPU cores
)

model_xgb.fit(
    X_train_final, y_train,
    eval_set=[(X_test_final, y_test)],
    verbose=100                 # Print progress every 100 rounds
)

# =====================================================================
# 9. COMPREHENSIVE PERFORMANCE REPORTING
# =====================================================================
print("\n" + "=" * 65)
print("  PHASE 3 PERFORMANCE METRICS")
print("=" * 65)

y_pred  = model_xgb.predict(X_test_final)
y_proba = model_xgb.predict_proba(X_test_final)

# ── Accuracy ─────────────────────────────────────────────────────────
acc = accuracy_score(y_test, y_pred)
print(f"\n  Overall Accuracy:   {acc * 100:.2f}%")

# ── Classification Report ────────────────────────────────────────────
print("\n  Detailed Clinical Performance Report:")
print(classification_report(y_test, y_pred, target_names=['Normal', 'Urgent', 'Emergency']))

# ── Confusion Matrix ─────────────────────────────────────────────────
print("  Confusion Matrix (rows=Actual, cols=Predicted):")
cm = confusion_matrix(y_test, y_pred)
print(f"  {'':12s}  Normal   Urgent   Emergency")
for i, label in enumerate(['Normal', 'Urgent', 'Emergency']):
    print(f"  {label:12s}  {cm[i][0]:6d}   {cm[i][1]:6d}   {cm[i][2]:9d}")

# ── ROC-AUC per class ────────────────────────────────────────────────
y_test_bin = label_binarize(y_test, classes=[0, 1, 2])
print("\n  ROC-AUC Score per Class:")
for i, cls_name in enumerate(['Normal', 'Urgent', 'Emergency']):
    auc = roc_auc_score(y_test_bin[:, i], y_proba[:, i])
    print(f"    {cls_name:12s}:  AUC = {auc:.4f}")

overall_auc = roc_auc_score(y_test_bin, y_proba, multi_class='ovr', average='macro')
print(f"    {'Macro OvR':12s}:  AUC = {overall_auc:.4f}")

# ── 5-Fold Stratified Cross-Validation ───────────────────────────────
print("\n  Running 5-Fold Stratified Cross-Validation...")
print("  (This gives a more honest accuracy estimate across all data splits)")

skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

# Use full dataset for CV
X_all = pd.concat([X_train_final, X_test_final], axis=0)
y_all = pd.concat([y_train, y_test], axis=0)

cv_scores = cross_val_score(model_xgb, X_all, y_all, cv=skf, scoring='accuracy', n_jobs=-1)
print(f"\n  CV Fold Scores: {[f'{s*100:.2f}%' for s in cv_scores]}")
print(f"  Mean Accuracy:  {cv_scores.mean()*100:.2f}% ± {cv_scores.std()*100:.2f}%")

# =====================================================================
# EXPORT PHASE 3 PRODUCTION ARTIFACTS
# =====================================================================
print("\n" + "=" * 65)
print("  EXPORTING PHASE 3 ARTIFACTS")
print("=" * 65)

joblib.dump(model_xgb, 'phase3_model.pkl')
joblib.dump(scaler,    'phase3_scaler.pkl')
joblib.dump(tfidf,     'phase3_tfidf.pkl')

print("\n  ✓ phase3_model.pkl   — XGBoost classifier")
print("  ✓ phase3_scaler.pkl  — StandardScaler (11 features)")
print("  ✓ phase3_tfidf.pkl   — TF-IDF bigram vectorizer (150 features)")
print("\n  Phase 3 training complete. Run `python app.py` to serve the upgraded model.")
print("=" * 65)
