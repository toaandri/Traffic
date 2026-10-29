import html
from pathlib import Path


def export_html(report: dict, directory: Path):
    def value(number):
        return "—" if number is None else f"{number:.2f}"

    rows = []
    for result in report["runs"]:
        for kind, label in (("vehicles", "Véhicules"), ("pedestrians", "Piétons")):
            measures = result[kind]
            rows.append(
                f"<tr><td>{result['seed']}</td><td>{result['controller']}</td>"
                f"<td>{label}</td><td>{measures['arrived']}</td>"
                f"<td>{measures['unfinished']}</td><td>{measures['not_departed']}</td>"
                f"<td>{value(measures['mean_waiting_time'])}</td>"
                f"<td>{value(measures['mean_travel_time'])}</td></tr>"
            )
    name = html.escape(report["scenario"]["name"])
    content = f"""<!doctype html><html lang="fr"><meta charset="utf-8">
<title>Traffic — {name}</title><style>body{{font:16px Segoe UI,Arial;margin:48px;color:#183041}}
table{{border-collapse:collapse;width:100%}}th,td{{padding:12px;border-bottom:1px solid #ccd8df;text-align:left}}
th{{background:#edf1f5}}h1{{font-size:28px}}p{{max-width:900px;line-height:1.6}}</style>
<h1>{name}</h1><p>Campagne reproductible : {len(report["runs"])} essais ; graines
{html.escape(str(report["seeds"]))}. Durée {report["scenario"]["duration"]} s.</p>
<table><tr><th>Graine</th><th>Contrôleur</th><th>Agents</th><th>Arrivés</th><th>Non arrivés</th>
<th>Non partis</th><th>Attente moyenne (s)</th><th>Trajet moyen (s)</th></tr>{"".join(rows)}</table>
<p>{html.escape(report["interpretation"])} Les mesures de simulation ne constituent pas des
prédictions de trafic réel validées.</p><p>Versions : {html.escape(str(report["versions"]))}</p></html>"""
    (directory / "report.html").write_text(content, encoding="utf-8")
