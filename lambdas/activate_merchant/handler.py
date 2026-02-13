import pg8000.native

def handler(event, context):
    merchant_id = event.get("merchantId")
    if not merchant_id:
        return {"error": "Missing merchantId"}

    try:
        conn = pg8000.native.Connection(
            user="merchant",
            password="merchant",
            host="merchant-postgres",
            database="merchantdb"
        )

        # ensure risk exists
        rows = conn.run(
            "SELECT score FROM risk WHERE merchant_id = :id",
            id=merchant_id
        )

        if not rows:
            return {"error": "Merchant risk not evaluated"}

        score = rows[0][0]

        if score < 50:
            status = "REJECTED"
        else:
            status = "ACTIVE"

        conn.run(
            "UPDATE merchants SET name = name WHERE merchant_id = :id",
            id=merchant_id
        )

        conn.close()

        return {
            "merchantId": merchant_id,
            "status": status,
            "riskScore": score
        }

    except Exception as e:
        return {"error": f"Activation failed: {str(e)}"}
