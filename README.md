# Vertical Drama API

Rails API for short-form episodic video. Videos are uploaded and streamed by [Mux Video]; Rails stores only Mux identifiers and
enforces the application's access rules.

## Setup

1. Copy `.env.example` to `.env` and add the Mux credentials. Do not commit
   `.env`.
2. Create the databases and run migrations:

   ```sh
   bin/rails db:prepare
   ```

3. Run the API with `bin/rails server`.
# Vertical-drama-backend
