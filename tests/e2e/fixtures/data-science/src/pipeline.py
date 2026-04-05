"""Data processing pipeline — load, transform, train, evaluate."""
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score


def load_data(path: str) -> pd.DataFrame:
    return pd.read_csv(path)


def train_model(df: pd.DataFrame, target_col: str):
    X = df.drop(columns=[target_col])
    y = df[target_col]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
    model = RandomForestClassifier()
    model.fit(X_train, y_train)
    preds = model.predict(X_test)
    return model, accuracy_score(y_test, preds)
