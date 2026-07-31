# Cockpit — Projekt- & Aufgabenübersicht

Ein eigenständiger Prototyp (eine einzige HTML-Datei, kein Build, keine
Abhängigkeiten) für die **Ticket-/Aufgabenanzeige** eines Programms. Öffne
einfach [`index.html`](index.html) im Browser.

> Hinweis: Der Cockpit-Prototyp ist unabhängig von der Home-Assistant-Integration
> (`custom_components/presenceguard/`) und wird von deren CI (`ruff`, `hassfest`,
> HACS, import-check) nicht berührt.

## Funktionen

### 1. Umschaltbare Ansicht — Liste ↔ Timeline
Oben rechts lässt sich die Anzeige der Tickets zwischen **Liste** und
**Timeline** umschalten. Die Timeline zeigt auf einer Zeitachse (inkl.
„Heute"-Markierung), **wann welche Aufgabe fertig sein muss** — Balken sind nach
Status eingefärbt, Meilensteine als Rauten dargestellt.

### 2. Zwei Ebenen — Meilensteine und Storys getrennt
Die Panels sind bewusst in **zwei Ebenen** aufgeteilt:

| Ebene | Panel | Frage, die es beantwortet |
|-------|-------|---------------------------|
| **Ebene 1** | Meilensteine | *Wo muss (im Meilenstein) neu geplant werden?* — Fortschritt, Fälligkeit, „⚠ neu planen" bei Überfälligkeit |
| **Ebene 2** | Storys & Aufgaben | *Welche Aufgabe muss als Nächstes bearbeitet werden?* |

So sieht man auf einen Blick, ob es ein **operatives** Problem (eine Aufgabe)
oder ein **Planungsproblem** (ein Meilenstein) ist.

### 3. Projekttyp Wasserfall / Agil (einmalig einstellbar)
Unter **⚙︎ Projekt-Details** wird der Projekttyp festgelegt — das macht man
einmal, danach steuert er die Darstellung. Die Wahl wird pro Projekt im
`localStorage` gespeichert.

### 4. Agil = Kanban (wenn der Platz reicht)
- **Agil** → Ebene 2 wird als **Kanban-Board** nach Status dargestellt
  (Backlog · To Do · In Arbeit · Review · Fertig). Bei zu wenig Breite
  (< 900 px) fallen die Spalten responsiv untereinander (mit Hinweis).
- **Wasserfall** → Ebene 2 wird als nach Meilenstein gruppierte **Liste**
  dargestellt, mit Status und Fälligkeitsdatum je Aufgabe.

## Aufbau

Alles in `index.html`:

- **Beispieldaten** (`DATA`) — zwei Projekte: *Apollo* (agil) und *Titan*
  (wasserfall). Anzupassen bzw. später gegen eine echte Datenquelle
  (z. B. GitHub-Issues/-Milestones) auszutauschen.
- **Status** (`STATUS`) — definiert die Kanban-Spalten und Farben.
- **Render-Funktionen** — `renderMilestones` (Ebene 1), `renderStories`
  (Ebene 2: `buildKanban` / `buildGroupedList`) und `renderTimeline`.

## Nächste Schritte (Ideen)

- Datenquelle anbinden (GitHub-Milestones = Ebene 1, Issues = Ebene 2).
- Drag & Drop im Kanban zum Statuswechsel.
- Filter nach Zuständigem / Fälligkeit.
