from flask import Flask, request, jsonify
import joblib
import pandas as pd
import numpy as np

print("=" * 65)
print("  PHASE 3 TRIAGE API — XGBOOST MULTIMODAL ENGINE")
print("=" * 65)

app = Flask(__name__)

# =====================================================================
# LOAD PHASE 3 TRAINED ARTIFACTS INTO RAM
# =====================================================================
try:
    model  = joblib.load('phase3_model.pkl')
    scaler = joblib.load('phase3_scaler.pkl')
    tfidf  = joblib.load('phase3_tfidf.pkl')
    print("\n  ✓ All Phase 3 ML artifacts loaded successfully.")
    print(f"  ✓ TF-IDF vocabulary size: {len(tfidf.vocabulary_)} terms")
except Exception as e:
    print(f"\n  CRITICAL ERROR LOADING ARTIFACTS: {str(e)}")
    print("  → Run `python phase3_upgraded_engine.py` first to generate the artifacts.")

# Feature column names — must match training order exactly
NUMERICAL_COLS = [
    'Age', 'heart_rate', 'systolic_bp', 'temperature', 'o2_sat',
    'shock_index',
    'pulse_pressure_proxy', 'hypoxia_flag', 'tachycardia_flag',
    'hypotension_flag', 'age_risk_score'
]

CATEGORIES = {0: "Normal", 1: "Urgent", 2: "Emergency"}


# =====================================================================
# HELPER: FEATURE ENGINEERING (mirrors training pipeline exactly)
# =====================================================================
def engineer_features(age, hr, sbp, temp, o2):
    """
    Reproduces the same 11 clinical features computed during training.
    Must be kept in sync with phase3_upgraded_engine.py.
    """
    shock_index          = hr / sbp
    pulse_pressure_proxy = sbp * 0.4
    hypoxia_flag         = 1 if o2  <= 94  else 0
    tachycardia_flag     = 1 if hr  >  100 else 0
    hypotension_flag     = 1 if sbp <  90  else 0
    age_risk_score       = 1 if age >  65  else 0

    return {
        'Age':                  [age],
        'heart_rate':           [hr],
        'systolic_bp':          [sbp],
        'temperature':          [temp],
        'o2_sat':               [o2],
        'shock_index':          [shock_index],
        'pulse_pressure_proxy': [pulse_pressure_proxy],
        'hypoxia_flag':         [hypoxia_flag],
        'tachycardia_flag':     [tachycardia_flag],
        'hypotension_flag':     [hypotension_flag],
        'age_risk_score':       [age_risk_score],
    }, shock_index, hypoxia_flag, tachycardia_flag, hypotension_flag, age_risk_score


# =====================================================================
# HELPER: DYNAMIC CLINICAL EXPLANATION GENERATOR
# =====================================================================
def build_explanation(o2, shock_index, temp, hr, sbp, age,
                       hypoxia_flag, tachycardia_flag,
                       hypotension_flag, age_risk_score,
                       symptom_text):
    bullets = []

    # O2 Saturation
    if o2 <= 90:
        bullets.append(
            f"Severe hypoxia ({o2:.0f}% O₂). Critical respiratory distress risk."
        )
    elif hypoxia_flag:
        bullets.append(
            f"Mild hypoxemia ({o2:.0f}% O₂ Sat). Supplemental oxygen advised."
        )

    # Shock Index
    if shock_index >= 1.0:
        bullets.append(
            f"Critical Shock Index {shock_index:.2f} (HR {hr:.0f} / SBP {sbp:.0f}). "
            f"Immediate haemodynamic intervention required."
        )
    elif shock_index >= 0.7:
        bullets.append(
            f"Borderline Shock Index {shock_index:.2f}. Cardiovascular monitoring advised."
        )

    # Heart Rate
    if tachycardia_flag:
        bullets.append(
            f"Tachycardia detected (HR {hr:.0f} bpm > 100). Cardiac workload elevated."
        )

    # Blood Pressure
    if hypotension_flag:
        bullets.append(
            f"Hypotension detected (SBP {sbp:.0f} mmHg < 90). Circulatory compromise risk."
        )

    # Temperature
    if temp >= 38.5:
        bullets.append(
            f"High-grade pyrexia ({temp:.1f}°C). Systemic infection protocol activated."
        )
    elif temp <= 35.5:
        bullets.append(
            f"Hypothermia risk ({temp:.1f}°C). Core temperature stabilisation required."
        )

    # Age
    if age_risk_score:
        bullets.append(
            f"Elderly patient ({age:.0f} yrs). Elevated physiological vulnerability applied."
        )

    # NLP keyword flags
    HIGH_RISK_TERMS = [
        'chest', 'pain', 'pressure', 'crushing', 'breath', 'bleeding',
        'fracture', 'unconscious', 'seizure', 'stroke', 'cardiac', 'arrest',
        'trauma', 'shortness', 'unresponsive', 'syncope'
    ]
    matched = [w for w in HIGH_RISK_TERMS if w in symptom_text]
    if matched:
        bullets.append(
            f"NLP clinical flags detected: {', '.join(matched)}."
        )

    if not bullets:
        bullets.append(
            "All vitals and clinical keywords within expected baseline ranges."
        )

    return " | ".join(bullets)


# =====================================================================
# PREDICTION ENDPOINT
# =====================================================================
@app.route('/predict', methods=['POST'])
def predict_triage():
    try:
        data = request.json
        if not data:
            return jsonify({"error": "No JSON payload received"}), 400

        # ── 1. Extract raw inputs ──────────────────────────────────────
        age          = float(data.get('age', 40))
        hr           = float(data.get('heart_rate', 80))
        sbp          = float(data.get('systolic_bp', 120))
        temp         = float(data.get('temperature', 36.5))
        o2           = float(data.get('o2_sat', 98))
        symptom_text = str(data.get('symptom_text', '')).lower().strip()

        # ── 2. Feature engineering (11 clinical features) ─────────────
        num_dict, shock_index, hypoxia_flag, tachycardia_flag, \
            hypotension_flag, age_risk_score = engineer_features(age, hr, sbp, temp, o2)

        df_num_raw = pd.DataFrame(num_dict)

        # ── 3. Scale numerical features ───────────────────────────────
        scaled_num    = scaler.transform(df_num_raw)
        df_num_scaled = pd.DataFrame(scaled_num, columns=NUMERICAL_COLS)

        # ── 4. TF-IDF text vectorization (150 bigram features) ────────
        text_vector = tfidf.transform([symptom_text]).toarray()
        n_text      = text_vector.shape[1]
        text_cols   = [f"word_{i}" for i in range(n_text)]
        df_text     = pd.DataFrame(text_vector, columns=text_cols)

        # ── 5. Feature fusion ─────────────────────────────────────────
        X_final = pd.concat([df_num_scaled, df_text], axis=1)

        # ── 6. XGBoost inference ──────────────────────────────────────
        prediction_class = int(model.predict(X_final)[0])
        probabilities    = model.predict_proba(X_final)[0]

        predicted_label  = CATEGORIES[prediction_class]
        confidence_score = float(np.max(probabilities))

        # ── 7. Clinical explanation ───────────────────────────────────
        explanation = build_explanation(
            o2, shock_index, temp, hr, sbp, age,
            hypoxia_flag, tachycardia_flag,
            hypotension_flag, age_risk_score,
            symptom_text
        )

        # ── 8. Build response ─────────────────────────────────────────
        return jsonify({
            "triage_category":    predicted_label,
            "confidence_score":   f"{confidence_score * 100:.2f}%",

            # Per-class probability breakdown (new in Phase 3)
            "class_probabilities": {
                "Normal":    f"{probabilities[0] * 100:.2f}%",
                "Urgent":    f"{probabilities[1] * 100:.2f}%",
                "Emergency": f"{probabilities[2] * 100:.2f}%"
            },

            "clinical_explanation": explanation,

            # Extended metrics payload
            "metrics_analyzed": {
                "shock_index":          round(shock_index, 3),
                "pulse_pressure_proxy": round(sbp * 0.4, 1),
                "hypoxia_flag":         bool(hypoxia_flag),
                "tachycardia_flag":     bool(tachycardia_flag),
                "hypotension_flag":     bool(hypotension_flag),
                "elderly_risk_flag":    bool(age_risk_score),
                "age":                  age,
                "engine":               "Phase 3 XGBoost Multimodal"
            }
        }), 200

    except Exception as e:
        return jsonify({"error": f"Inference error: {str(e)}"}), 500


# =====================================================================
# HEALTH CHECK ENDPOINT
# =====================================================================
@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status":  "online",
        "engine":  "Phase 3 XGBoost Multimodal Triage",
        "version": "3.0"
    }), 200


if __name__ == '__main__':
    print("\n  Starting server on http://0.0.0.0:5000")
    print("  POST to /predict | GET /health\n")
    app.run(host='0.0.0.0', port=5000, debug=True)