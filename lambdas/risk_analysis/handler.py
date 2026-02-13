import pg8000.native

def handler(event, context):
    merchant_id = event.get("merchantId")
    result = event.get("result", "CLEAR")

    if not merchant_id:
        return {"error": "Missing merchantId"}

    try:
        conn = pg8000.native.Connection(
            user="merchant",
            password="merchant",
            host="merchant-postgres",
            database="merchantdb"
        )

        score = 80 if result == "CLEAR" else 20

        rows = conn.run(
            "INSERT INTO risk (merchant_id, score) VALUES (:merchant_id, :score) RETURNING risk_id",
            merchant_id=merchant_id,
            score=score
        )

        conn.close()

        return {
            "riskId": rows[0][0],
            "score": score
        }

    except Exception as e:
        return {"error": f"Risk analysis insert failed: {str(e)}"}
