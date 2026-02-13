import pg8000.native

def handler(event, context):
    kyc_id = event.get("kycId")
    status = event.get("status", "APPROVED")

    if not kyc_id:
        return {"error": "Missing kycId"}

    try:
        conn = pg8000.native.Connection(
            user="merchant",
            password="merchant",
            host="merchant-postgres",
            database="merchantdb"
        )

        conn.run(
            "UPDATE kyc SET status = :status WHERE kyc_id = :kyc_id",
            status=status,
            kyc_id=kyc_id
        )

        conn.close()

        return {
            "kycId": kyc_id,
            "status": status
        }

    except Exception as e:
        return {"error": f"KYC update failed: {str(e)}"}
