# UVM Panel

A full web-based LXC container VPS management panel with a Flask backend and admin dashboard.

## Setup

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
python3 uvm.py
```

## Configuration

Set via environment variables (see `uvm.py` for the full list), including:

- `PANEL_NAME` - display name shown in the UI (default: `UVM PANEL`)
- `SECRET_KEY` - Flask session secret
- `DATABASE_PATH` - path to the SQLite database (default: `uvm.db`)
- `HOST` / `PORT` - bind address (default: `0.0.0.0:5000`)
- `MAIN_ADMIN_USERNAME` / `MAIN_ADMIN_PASSWORD` / `MAIN_ADMIN_EMAIL` - initial admin account
- `YOUR_SERVER_IP` - server IP used for generated links
- `DEFAULT_STORAGE_POOL` - default LXC storage pool
