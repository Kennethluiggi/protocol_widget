import tkinter as tk
from dataclasses import dataclass
from datetime import datetime, time
import os

# --- Windows chime ---
try:
    import pygame
    pygame.mixer.init()

    _sound_path = os.path.join(os.path.dirname(__file__), "chime.mp3")
    _ding = pygame.mixer.Sound(_sound_path)  # loads once for instant playback
    #ding.set_volume(1.0)

    def chime():
        try:
            _ding.play()
        except Exception:
            pass
            

except Exception:
    def chime():
        pass


@dataclass
class RowDef:
    start: time
    end: time
    label: str
    title: str
    bullets: list[str] | None = None


ROWS = [
    RowDef(time(8, 0),  time(8, 30), "8:00–8:30 am",  "Dog Walk + Duolingo"),
    RowDef(time(8, 30), time(8, 45), "8:30–8:45 am",  "Cold Water → Half-Caf Coffee"),
    RowDef(time(8, 45), time(8, 45), "8:45 am",       "Sit at Desk Immediately (No Phone)"),
    RowDef(time(8, 45), time(8, 55), "8:45–8:55 am",  "Brain Dump (Whiteboard)"),
    RowDef(time(8, 55), time(9, 35), "8:55–9:35 am",  "40-Minute Writing Block"),
    RowDef(time(9, 35), time(10, 35), "9:35–10:35 am", "Opportunity Creation Block", bullets=[
        "1 Hiring Manager Message",
        "3 Strategic Connections",
        "Apply to New Posting",
    ]),
    RowDef(time(10, 35), time(11, 5), "10:35–11:05 am", "Reading (30 min)"),
    RowDef(time(13, 0), time(14, 0), "1:00–2:00 pm",  "Focus Block", bullets=[
        "M/W/F – Interview Prep / LinkedIn Post / Portfolio Webpage",
        "T/Th – API Project (Max 60 min)",
    ]),
]

TOP_LINES = [
    "WHEN I SIT DOWN, I START.",
    "I DON’T NEGOTIATE WITH TODAY.",
    "FINISH FIRST. IMPROVE SECOND.",
]


class ProtocolWidget:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Daily Execution Protocol")
        self.root.attributes("-topmost", True)
        self.root.configure(bg="white")

        # ---- Colors ----
        self.header_color = "#153E66"
        self.footer_color = "#0F5132"
        self.active_bg = "#FBE7DD"   # mellow peach highlight
        self.normal_bg = "#FFFFFF"
        self.gridline = "#D0D0D0"
        self.header_bg = "#EAEAEA"

        # ---- Fonts ----
        # Header should be: big -> smaller -> smaller (Word-like)
        self.font_header_1 = ("Segoe UI Semibold", 24)
        self.font_header_2 = ("Segoe UI Semibold", 16)
        self.font_header_3 = ("Segoe UI Semibold", 12)

        # Table fonts
        self.font_colhdr = ("Segoe UI Semibold", 12)
        self.font_time = ("Segoe UI", 10)
        self.font_title = ("Segoe UI Semibold", 11)
        self.font_bullet = ("Segoe UI", 10)
        self.font_clock = ("Segoe UI", 9)

        # Footer fonts (Word-like emphasis)
        self.font_footer_consistency = ("Segoe UI", 14, "italic")
        self.font_footer_builds = ("Segoe UI Semibold", 18)
        self.font_footer_provider = ("Segoe UI Black", 34)

        self.active_index = None

        # ---- Header ----
        header = tk.Frame(self.root, bg="white")
        header.pack(fill="x", padx=12, pady=(10, 8))

        tk.Label(header, text=TOP_LINES[0], font=self.font_header_1,
                 fg=self.header_color, bg="white").pack(anchor="center")
        tk.Label(header, text=TOP_LINES[1], font=self.font_header_2,
                 fg=self.header_color, bg="white").pack(anchor="center", pady=(6, 0))
        tk.Label(header, text=TOP_LINES[2], font=self.font_header_3,
                 fg=self.header_color, bg="white").pack(anchor="center", pady=(6, 0))

        # ---- TABLE (single shared grid) ----
        table = tk.Frame(self.root, bg="white")
        table.pack(fill="both", expand=True, padx=12, pady=8)

        # Shared columns (alignment)
        table.grid_columnconfigure(0, weight=0, minsize=140)
        table.grid_columnconfigure(1, weight=1)
        table.grid_columnconfigure(2, weight=0, minsize=60)

        # Column headers row
        self._cell(table, 0, 0, "Time", bg=self.header_bg, font=self.font_colhdr, padx=10, pady=10, anchor="w")
        self._cell(table, 0, 1, "Action", bg=self.header_bg, font=self.font_colhdr, padx=10, pady=10, anchor="w")
        self._cell(table, 0, 2, "✓", bg=self.header_bg, font=self.font_colhdr, padx=10, pady=10, anchor="e")

        # Separator line under header
        tk.Frame(table, bg=self.gridline, height=1).grid(row=1, column=0, columnspan=3, sticky="ew", pady=(0, 6))

        # Store row widgets so we can recolor entire row cleanly
        self.row_widgets = []
        self.check_vars = []

        grid_row = 2

        for r in ROWS:
            row_w = []

            # Time cell
            time_lbl = tk.Label(table, text=r.label, font=self.font_time, bg=self.normal_bg)
            time_lbl.grid(row=grid_row, column=0, sticky="nw", padx=10, pady=10)
            row_w.append(time_lbl)

            # Action cell (stacked title + bullet grid)
            action_frame = tk.Frame(table, bg=self.normal_bg)
            action_frame.grid(row=grid_row, column=1, sticky="nwe", padx=10, pady=8)
            action_frame.grid_columnconfigure(0, weight=1)
            row_w.append(action_frame)

            title_lbl = tk.Label(
                action_frame,
                text=r.title,
                font=self.font_title,
                bg=self.normal_bg,
                anchor="w",
                justify="left"
            )
            title_lbl.grid(row=0, column=0, sticky="w")
            row_w.append(title_lbl)

            if r.bullets:
                bullets_frame = tk.Frame(action_frame, bg=self.normal_bg)
                bullets_frame.grid(row=1, column=0, sticky="w", pady=(6, 0))
                row_w.append(bullets_frame)

                for i, b in enumerate(r.bullets):
                    dot = tk.Label(bullets_frame, text="•", font=self.font_bullet, bg=self.normal_bg)
                    dot.grid(row=i, column=0, sticky="nw", padx=(0, 8))
                    txt = tk.Label(bullets_frame, text=b, font=self.font_bullet, bg=self.normal_bg, justify="left")
                    txt.grid(row=i, column=1, sticky="nw")
                    row_w.extend([dot, txt])

            # Checkbox cell
            v = tk.BooleanVar(value=False)
            cb = tk.Checkbutton(table, variable=v, bg=self.normal_bg)
            cb.grid(row=grid_row, column=2, sticky="n", padx=10, pady=10)
            row_w.append(cb)
            self.check_vars.append(v)

            self.row_widgets.append(row_w)

            # Separator line after each row
            tk.Frame(table, bg=self.gridline, height=1).grid(row=grid_row + 1, column=0, columnspan=3, sticky="ew")
            grid_row += 2

        # ---- Footer (two-line, with underline) ----
        footer = tk.Frame(self.root, bg="white")
        footer.pack(fill="x", padx=12, pady=(10, 6))

        line1 = tk.Frame(footer, bg="white")
        line1.pack(anchor="center")
        tk.Label(line1, text="CONSISTENCY", font=self.font_footer_consistency,
                 fg=self.footer_color, bg="white").pack(side="left")
        tk.Label(line1, text="  BUILDS", font=self.font_footer_builds,
                 fg=self.footer_color, bg="white").pack(side="left")

        provider_lbl = tk.Label(
            footer,
            text="THE PROVIDER.",
            font=self.font_footer_provider,
            fg=self.footer_color,
            bg="white"
        )
        provider_lbl.pack(anchor="center", pady=(6, 0))

        # underline canvas (sized after layout pass)
        self.underline_canvas = tk.Canvas(footer, height=8, bg="white", highlightthickness=0)
        self.underline_canvas.pack(anchor="center", pady=(0, 4))

        # Clock
        self.clock_label = tk.Label(self.root, text="", font=self.font_clock, fg="#666666", bg="white")
        self.clock_label.pack(anchor="e", padx=12, pady=(0, 10))

        # ---- Final layout pass: auto-size window to content (no dragging needed) ----
        self.root.update_idletasks()

        # underline to match provider width
        text_w = provider_lbl.winfo_reqwidth()
        self.underline_canvas.configure(width=text_w)
        self.underline_canvas.delete("all")
        self.underline_canvas.create_line(0, 4, text_w, 4, fill=self.footer_color, width=3)

        # auto geometry to fit everything on launch
        w = self.root.winfo_reqwidth()
        h = self.root.winfo_reqheight()
        self.root.geometry(f"{w}x{h}")
        self.root.minsize(w, h)

        # Start loop
        self.tick()

    def _cell(self, parent, r, c, text, bg, font, padx, pady, anchor):
        lbl = tk.Label(parent, text=text, bg=bg, font=font, anchor=anchor)
        lbl.grid(row=r, column=c, sticky="ew", padx=0, pady=0)
        lbl.configure(padx=padx, pady=pady)
        lbl.configure(highlightthickness=1, highlightbackground=self.gridline)
        return lbl

    def time_in_range(self, now_t: time, start: time, end: time) -> bool:
        # Anchor-time row (start == end) highlights only at that exact minute
        if start == end:
            return (now_t.hour, now_t.minute) == (start.hour, start.minute)
        return start <= now_t < end

    def set_row_bg(self, row_index: int, bg: str):
        for w in self.row_widgets[row_index]:
            try:
                w.configure(bg=bg)
            except Exception:
                pass

    def tick(self):
        now = datetime.now()
        now_t = now.time().replace(second=0, microsecond=0)
        self.clock_label.configure(text=now.strftime("%I:%M %p").lstrip("0"))

        current = None
        for i, r in enumerate(ROWS):
            if self.time_in_range(now_t, r.start, r.end):
                current = i
                break

        for i in range(len(ROWS)):
            self.set_row_bg(i, self.active_bg if i == current else self.normal_bg)

        # chime only on transitions (not on first paint)
        if current is not None and current != self.active_index:
            if self.active_index is not None:
                chime()
            self.active_index = current

        self.root.after(10_000, self.tick)


if __name__ == "__main__":
    ProtocolWidget().root.mainloop()
