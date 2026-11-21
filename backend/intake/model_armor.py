"""L2: Model Armor screening (europe-west3). Caller treats any exception as BLOCK UPSTREAM_UNAVAILABLE."""
from functools import lru_cache

from backend.common import config


@lru_cache(maxsize=1)
def _client():
    from google.cloud import modelarmor_v1
    return modelarmor_v1.ModelArmorClient(
        client_options={"api_endpoint": "modelarmor.europe-west3.rep.googleapis.com"})


def screen(text: str) -> dict:
    """-> {match: bool, confidence: str}"""
    from google.cloud import modelarmor_v1 as ma
    res = _client().sanitize_user_prompt(request=ma.SanitizeUserPromptRequest(
        name=config.MODEL_ARMOR_TEMPLATE, user_prompt_data=ma.DataItem(text=text)))
    r = res.sanitization_result
    match = r.filter_match_state == ma.FilterMatchState.MATCH_FOUND
    conf = ""
    try:
        conf = r.filter_results["pi_and_jailbreak"].pi_and_jailbreak_filter_result.confidence_level.name
    except Exception:
        pass
    return {"match": bool(match), "confidence": conf or ("MATCH" if match else "NONE")}
