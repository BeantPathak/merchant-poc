import json
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

        # verify merchant exists (prevents silent FK explosion)
        rows = conn.run(
            "SELECT merchant_id FROM merchants WHERE merchant_id = :merchant_id",
            merchant_id=merchant_id
        )

        if not rows:
            conn.close()
            return {"error": "Merchant not found"}

        # create KYC entry
        result = conn.run(
            """
            INSERT INTO kyc (merchant_id, status)
            VALUES (:merchant_id, 'PENDING')
            RETURNING kyc_id
            """,
            merchant_id=merchant_id
        )

        conn.close()

        return {
            "kycId": result[0][0],
            "status": "PENDING"
        }

    except Exception as e:
        return {"error": f"KYC insert failed: {str(e)}"}
