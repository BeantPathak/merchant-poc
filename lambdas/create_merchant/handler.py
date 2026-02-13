import pg8000.native

def handler(event, context):
    name = event.get("name", "Test Merchant")

    try:
        conn = pg8000.native.Connection(
            user="merchant",
            password="merchant",
            host="merchant-postgres",
            database="merchantdb"
        )

        rows = conn.run(
            "INSERT INTO merchants (name) VALUES (:name) RETURNING merchant_id",
            name=name
        )

        conn.close()

        return {
            "merchantId": rows[0][0]
        }

    except Exception as e:
        return {
            "error": f"DB insert failed: {str(e)}"
        }
