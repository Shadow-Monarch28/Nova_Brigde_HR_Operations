"""
================================================================================
  NovaBridge Solutions — BPO/CSR Synthetic Dirty Dataset Generator v2
  Portfolio Project | Data Analyst Resume Showcase
  Files   : interaction_file.csv        (~1 Million rows)
            performance_file.csv        (~369 rows)
            survey_report.csv           (~205K rows)
            schedule_adherence_file.csv (~1,496 rows)
================================================================================
"""
import random, warnings
import numpy  as np
import pandas as pd
from faker    import Faker
from datetime import date, timedelta

warnings.filterwarnings("ignore")
SEED = 42
random.seed(SEED); np.random.seed(SEED)
fake = Faker(); Faker.seed(SEED)

# ── Master data ───────────────────────────────────────────────────────────────
AGENTS = [
    ("AGT001","Priya","Sharma","Noida","F"),    ("AGT002","Rajiv","Menon","Noida","M"),
    ("AGT003","Anjali","Verma","Gurgaon","F"),  ("AGT004","Vikram","Nair","Noida","M"),
    ("AGT005","Deepika","Iyer","Gurgaon","F"),  ("AGT006","Arjun","Pillai","Gurgaon","M"),
    ("AGT007","Jessica","Thompson","New York","F"),("AGT008","Michael","Anderson","New York","M"),
    ("AGT009","Ashley","Williams","New York","F"),("AGT010","Brandon","Clark","New York","M"),
    ("AGT011","Samantha","Lewis","New York","F"),("AGT012","Tyler","Harris","New York","M"),
    ("AGT013","Danielle","Robinson","Ontario","F"),("AGT014","Kevin","Martin","Ontario","M"),
    ("AGT015","Lauren","Jackson","Ontario","F"),("AGT016","Marcus","White","Ontario","M"),
    ("AGT017","Tiffany","Davis","New York","F"),("AGT018","DeShawn","Johnson","New York","M"),
    ("AGT019","Latoya","Brown","Ontario","F"),  ("AGT020","Jermaine","Wilson","New York","M"),
    ("AGT021","Wei","Zhang","Noida","M"),       ("AGT022","Xiao","Liu","Gurgaon","F"),
    ("AGT023","Hao","Chen","Noida","M"),        ("AGT024","Yuki","Tanaka","Ontario","F"),
    ("AGT025","Kenji","Watanabe","Ontario","M"),("AGT026","Aiko","Nakamura","Gurgaon","F"),
    ("AGT027","Sophie","Tremblay","Ontario","F"),("AGT028","Luc","Bouchard","Ontario","M"),
    ("AGT029","Chloe","Gagnon","Ontario","F"),  ("AGT030","Ethan","Lefebvre","Ontario","M"),
]

TEAMS    = ["Team Alpha","Team Beta","Team Gamma","Team Delta"]
MANAGERS = ["Rachel Kim","David Osei","Meera Pillai","James Callahan"]
TEAM_MGR = {
    "Team Alpha" : "Rachel Kim",
    "Team Beta"  : "David Osei",
    "Team Gamma" : "Meera Pillai",
    "Team Delta" : "James Callahan"
}
AGENT_TEAM = {a[0]: TEAMS[(int(a[0][3:])-1) % 4] for a in AGENTS}
AGENT_MGR  = {a[0]: TEAM_MGR[AGENT_TEAM[a[0]]] for a in AGENTS}

# ── Agent performance profiles ────────────────────────────────────────────────
# Each agent gets a tier: top (30%), mid (50%), low (20%)
# This drives all metric generation — AHT, scores, CSAT etc.
random.seed(SEED)
AGENT_TIERS = {}
for a in AGENTS:
    aid = a[0]
    tier = random.choices(['top','mid','low'], weights=[30,50,20])[0]
    AGENT_TIERS[aid] = tier

# Performance profile per tier
TIER_PROFILE = {
    'top' : {'aht':(200,600),   'adherence':(88,99),  'util':(82,95),
             'nice':(82,100),   'kc':(80,100),        'comms':(82,100),
             'csat_weight':[3,5,10,28,40,14],          'callback_rate':(1,5)},
    'mid' : {'aht':(500,1200),  'adherence':(75,90),  'util':(68,85),
             'nice':(65,85),    'kc':(60,82),         'comms':(65,85),
             'csat_weight':[8,12,20,30,25,5],          'callback_rate':(4,10)},
    'low' : {'aht':(900,2500),  'adherence':(65,80),  'util':(55,72),
             'nice':(50,70),    'kc':(40,65),         'comms':(50,70),
             'csat_weight':[18,20,25,20,12,5],         'callback_rate':(8,20)},
}

# ── Team baselines ─────────────────────────────────────────────────────────────
# Each team has a performance baseline modifier
TEAM_BASELINE = {
    "Team Alpha" : {'adherence': 2,  'util': 1,  'aht_mult': 0.90, 'score_add': 3},
    "Team Beta"  : {'adherence': 0,  'util': 0,  'aht_mult': 1.00, 'score_add': 0},
    "Team Gamma" : {'adherence':-3,  'util':-2,  'aht_mult': 1.15, 'score_add':-4},
    "Team Delta" : {'adherence': 1,  'util': 2,  'aht_mult': 0.95, 'score_add': 2},
}

# ── Monthly seasonality ────────────────────────────────────────────────────────
# Multiplier applied to interaction volume and AHT per month
# Peaks in Jan (post-holiday), Oct-Nov (benefits season)
MONTH_SEASONALITY = {
    1:1.25, 2:0.95, 3:0.90, 4:0.88, 5:0.85, 6:0.87,
    7:0.90, 8:0.92, 9:0.95, 10:1.10, 11:1.20, 12:1.15
}

DOMAINS    = ["Payroll","HRFS","Health & Wealth","Direct Benefits","Retirement",
              "Recruiting","Learning","Time Keeping","Absence",
              "Life Benefit Specialists","On Floor Supervisor"]
SHIFTS     = ["Morning","Afternoon","Night"]
CHANNELS   = ["call","chat"]
DISPOSITIONS = ["Resolved","Escalated","Follow-up Required",
                "Transferred","Abandoned","Voicemail"]
US_VARS  = ["US","us","U.S.","USA","United States","U.S.A"]
CA_VARS  = ["Canada","canada","CA","CAN","CANADA"]

# ── Extended date range Jan 2024 → Apr 2026 ───────────────────────────────────
START  = date(2024, 1,  1)
END    = date(2026, 4, 30)
DRANGE = (END - START).days

# ── Helpers ───────────────────────────────────────────────────────────────────
def rand_date():
    return START + timedelta(days=random.randint(0, DRANGE))

def dirty_date(d):
    fmt = random.choices(
        ["%m/%d/%Y", "%Y-%m-%d", "%d-%m-%Y", "%b %d %Y"],
        [35, 35, 20, 10])[0]
    return d.strftime(fmt)

def dirty_country(b):
    return random.choice(US_VARS if b == "US" else CA_VARS)

def maybe_null(v, p=0.065):
    return None if random.random() < p else v

TYPOS = {
    "Jessica":"Jassica","Michael":"Micheal","Samantha":"Samanthha",
    "Priya":"Priyya","Rajiv":"Rajiev","DeShawn":"DeShawnn",
    "Danielle":"Daniell","Yuki":"Yukki","Sophie":"Soophie"
}
def dirty_name(n): return TYPOS.get(n,n) if random.random() < 0.04 else n
def dirty_case(t):
    r = random.random()
    return t.lower() if r < .10 else (t.upper() if r < .18 else t)
def ws(t):
    return ((" "*random.randint(1,3))+t+(" "*random.randint(1,3))) \
        if random.random() < .03 else t
def clamp(v, lo, hi): return max(lo, min(hi, v))

PERSON_POOL = [str(random.randint(100_000_000,999_999_999)) for _ in range(50_000)]
EMP_POOL    = [(fake.first_name(), fake.last_name()) for _ in range(5_000)]

# ── FILE 1 — Interaction ──────────────────────────────────────────────────────
def gen_interaction(target=1_000_000):
    print(f"[1/4] interaction_file.csv  ({target:,} rows) ...")
    base = int(target / 1.025)
    rows = []

    for i in range(base):
        a   = random.choice(AGENTS)
        aid, afn, aln, aloc, _ = a
        team = AGENT_TEAM[aid]
        mgr  = AGENT_MGR[aid]
        tier = AGENT_TIERS[aid]
        prof = TIER_PROFILE[tier]
        base_line = TEAM_BASELINE[team]

        d = rand_date()
        t = f"{random.randint(0,23):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"

        # AHT — agent tier + team modifier + monthly seasonality
        season  = MONTH_SEASONALITY.get(d.month, 1.0)
        aht_raw = random.randint(*prof['aht'])
        handle  = int(aht_raw * base_line['aht_mult'] * season)
        handle  = random.choices([handle, 0, 9999], [90, 5, 5])[0]
        hold    = random.randint(0, min(handle, 600)) if handle > 0 else 0
        wrap    = random.randint(0, 300)

        bc  = "Canada" if aloc == "Ontario" else "US"
        pid = random.choice(PERSON_POOL)
        ef, el = random.choice(EMP_POOL)

        # Disposition — top agents resolve more, low agents abandon/escalate more
        if tier == 'top':
            disp_weights = [45, 15, 10, 15, 8, 7]
        elif tier == 'mid':
            disp_weights = [30, 20, 15, 15, 12, 8]
        else:
            disp_weights = [15, 22, 18, 15, 22, 8]

        rows.append({
            "interaction_id"      : f"IXN{i+1:08d}",
            "agent_id"            : maybe_null(ws(aid)),
            "agent_first_name"    : maybe_null(ws(dirty_name(dirty_case(afn)))),
            "agent_last_name"     : maybe_null(ws(dirty_case(aln))),
            "agent_location"      : maybe_null(ws(dirty_case(aloc))),
            "person_id"           : maybe_null(pid),
            "employee_first_name" : maybe_null(ws(dirty_name(ef))),
            "employee_last_name"  : maybe_null(ws(el)),
            "country"             : maybe_null(dirty_country(bc)),
            "channel"             : maybe_null(dirty_case(random.choice(CHANNELS))),
            "interaction_date"    : maybe_null(dirty_date(d)),
            "interaction_time"    : maybe_null(t),
            "handle_time_seconds" : maybe_null(handle),
            "hold_time_seconds"   : maybe_null(hold),
            "wrap_time_seconds"   : maybe_null(wrap),
            "call_disposition"    : maybe_null(dirty_case(
                                        random.choices(DISPOSITIONS, disp_weights)[0])),
            "callback_flag"       : maybe_null(
                                        random.choices(["yes","no","YES","No"],
                                        [15,75,5,5])[0]),
            "manager_name"        : maybe_null(ws(mgr)),
            "team_name"           : maybe_null(ws(dirty_case(team))),
            "shift"               : maybe_null(dirty_case(random.choice(SHIFTS))),
            "domain"              : maybe_null(dirty_case(random.choice(DOMAINS))),
        })

        if (i+1) % 200_000 == 0:
            print(f"   ... {i+1:,} rows")

    dups = random.choices(rows, k=target-base)
    rows.extend(dups)
    random.shuffle(rows)
    df = pd.DataFrame(rows)

    # Inject negative handle times
    neg = np.random.random(len(df)) < 0.012
    df.loc[neg, "handle_time_seconds"] = df.loc[neg, "handle_time_seconds"].apply(
        lambda x: -abs(int(x)) if pd.notna(x) else x)

    print(f"   ✓ {len(df):,} rows, {len(df.columns)} cols")
    return df

# ── FILE 2 — Performance ──────────────────────────────────────────────────────
def gen_performance():
    print("[2/4] performance_file.csv ...")

    # Full month range Jan 2024 → Apr 2026 = 28 months
    MONTHS = pd.period_range("2024-01", periods=28, freq="M")
    rows   = []

    for a in AGENTS:
        aid, afn, aln, _, _ = a
        team  = AGENT_TEAM[aid]
        mgr   = AGENT_MGR[aid]
        tier  = AGENT_TIERS[aid]
        prof  = TIER_PROFILE[tier]
        bl    = TEAM_BASELINE[team]
        aname = f"{afn} {aln}"

        for m in MONTHS:
            mstr = random.choices(
                [str(m), m.strftime("%m-%Y"), m.strftime("%b %Y")],
                [40, 30, 30])[0]

            season = MONTH_SEASONALITY.get(m.month, 1.0)

            # Each metric uses agent tier + team baseline + monthly noise
            adherence = clamp(
                round(random.uniform(*prof['adherence']) + bl['adherence']
                      + random.uniform(-3, 3), 2), 60, 100)

            util = clamp(
                round(random.uniform(*prof['util']) + bl['util']
                      + random.uniform(-3, 3), 2), 50, 100)

            nice = clamp(
                round(random.uniform(*prof['nice']) + bl['score_add']
                      + random.uniform(-5, 5), 2), 40, 100)

            kc = clamp(
                round(random.uniform(*prof['kc']) + bl['score_add']
                      + random.uniform(-5, 5), 2), 30, 100)

            comms = clamp(
                round(random.uniform(*prof['comms']) + bl['score_add']
                      + random.uniform(-5, 5), 2), 40, 100)

            aht_raw = random.randint(*prof['aht'])
            aht = int(aht_raw * bl['aht_mult'] * season)
            aht = random.choices([aht, 0, 9999], [90, 5, 5])[0]

            cbs = random.randint(0, 150)
            cbr = round(cbs / max(random.randint(500, 2000), 1) * 100, 2)

            rows.append({
                "employee_id"              : maybe_null(ws(aid), .04),
                "agent_name"               : maybe_null(ws(dirty_name(aname)), .03),
                "manager_name"             : maybe_null(ws(mgr), .04),
                "team_name"                : maybe_null(ws(dirty_case(team)), .04),
                "month"                    : maybe_null(mstr, .02),
                "schedule_adherence_%"     : maybe_null(adherence, .06),
                "resource_utilization_%"   : maybe_null(util, .06),
                "comms_audit_score"        : maybe_null(comms, .06),
                "nice_evaluation_score"    : maybe_null(nice, .06),
                "kc_quiz_score"            : maybe_null(kc, .06),
                "aht_seconds"              : maybe_null(aht, .05),
                "total_callbacks"          : maybe_null(cbs, .05),
                "callback_rate_%"          : maybe_null(cbr, .05),
                "average_hold_time_seconds": maybe_null(random.randint(0, 400), .05),
            })

    df = pd.DataFrame(rows)

    # Add duplicates
    nd = int(len(df) * .025)
    df = pd.concat([df, df.sample(n=nd, random_state=SEED)], ignore_index=True)\
           .sample(frac=1, random_state=SEED).reset_index(drop=True)

    # Out-of-range values
    for col in ["comms_audit_score","nice_evaluation_score","kc_quiz_score"]:
        oor = np.random.random(len(df)) < 0.015
        df.loc[oor, col] = df.loc[oor, col].apply(
            lambda x: random.choice([-5, 101, 105]) if pd.notna(x) else x)

    print(f"   ✓ {len(df):,} rows, {len(df.columns)} cols")
    return df

# ── FILE 3 — Survey ───────────────────────────────────────────────────────────
def gen_survey(iids, n=205_000):
    print(f"[3/4] survey_report.csv  ({n:,} rows) ...")
    real     = random.choices(iids, k=int(n * .80))
    phantoms = [f"IXN{random.randint(9_000_000,9_999_999):08d}"
                for _ in range(int(n * .20))]
    all_ids  = real + phantoms
    random.shuffle(all_ids)

    VERBS = [
        "Great support, resolved quickly!","Agent was helpful and polite.",
        "Waited too long on hold.","Issue not resolved, very frustrated.",
        "Excellent experience overall.","Agent did not understand my problem.",
        "Quick resolution, thank you!","Very poor service today.",
        "Agent was professional and knowledgeable.","I had to call back multiple times.",
        None, None, None
    ]

    rows = []
    for i, iid in enumerate(all_ids):
        a   = random.choice(AGENTS)
        aid, afn, aln, aloc, _ = a
        mgr  = AGENT_MGR[aid]
        tier = AGENT_TIERS[aid]
        prof = TIER_PROFILE[tier]

        # CSAT driven by agent tier
        csat  = random.choices([1,2,3,4,5,6], prof['csat_weight'])[0]
        dsat  = "yes" if csat <= 2 else random.choices(["no","yes"], [92, 8])[0]

        bc   = "Canada" if aloc == "Ontario" else "US"
        ef, el = random.choice(EMP_POOL)

        rows.append({
            "survey_id"       : f"SVY{i+1:08d}",
            "interaction_id"  : iid,
            "employee_id"     : maybe_null(random.choice(PERSON_POOL), .07),
            "employee_name"   : maybe_null(f"{ef} {el}", .06),
            "agent_id"        : maybe_null(ws(aid), .05),
            "agent_name"      : maybe_null(ws(dirty_name(f"{afn} {aln}")), .05),
            "channel"         : maybe_null(dirty_case(random.choice(CHANNELS)), .04),
            "survey_date"     : maybe_null(dirty_date(rand_date()), .04),
            "csat_score"      : maybe_null(csat, .07),
            "dsat_flag"       : maybe_null(dirty_case(dsat), .06),
            "verbatim_comment": random.choice(VERBS),
            "country"         : maybe_null(dirty_country(bc), .06),
            "manager_name"    : maybe_null(ws(mgr), .05),
        })

        if (i+1) % 50_000 == 0:
            print(f"   ... {i+1:,} rows")

    df = pd.DataFrame(rows)
    nd = int(len(df) * .022)
    df = pd.concat([df, df.sample(n=nd, random_state=SEED)], ignore_index=True)\
           .sample(frac=1, random_state=SEED).reset_index(drop=True)

    print(f"   ✓ {len(df):,} rows, {len(df.columns)} cols")
    return df

# ── FILE 4 — Schedule ─────────────────────────────────────────────────────────
def gen_schedule():
    print("[4/4] schedule_adherence_file.csv ...")
    rows = []

    for i in range(DRANGE + 1):
        d    = START + timedelta(days=i)
        season = MONTH_SEASONALITY.get(d.month, 1.0)

        for team in TEAMS:
            mgr = TEAM_MGR[team]
            bl  = TEAM_BASELINE[team]

            # Scheduled hours — slight team variance
            sh = random.choice([8.0, 8.5, 9.0])

            # Actual hours — driven by team adherence baseline
            ah_base = sh * (0.85 + (bl['adherence'] * 0.005))
            ah = round(clamp(ah_base + random.uniform(-0.5, 0.5), 6.5, sh + 0.5), 2)

            # Adherence — team baseline + seasonal noise
            adh = clamp(
                round((ah/sh*100) + bl['adherence'] + random.uniform(-4, 4), 2),
                60, 100)

            # Shrinkage — teams with lower adherence have higher shrinkage
            shrink_base = 20 - (bl['adherence'] * 0.5)
            shrink = clamp(round(shrink_base + random.uniform(-5, 5), 2), 5, 35)

            sc = random.randint(6, 10)
            sp = random.randint(max(4, sc-3), sc)

            rows.append({
                "date"              : maybe_null(dirty_date(d), .03),
                "team_name"         : maybe_null(ws(dirty_case(team)), .04),
                "manager_name"      : maybe_null(ws(mgr), .04),
                "scheduled_hours"   : maybe_null(sh, .05),
                "actual_hours"      : maybe_null(ah, .05),
                "adherence_%"       : maybe_null(adh, .06),
                "shrinkage_%"       : maybe_null(shrink, .05),
                "agents_scheduled"  : maybe_null(sc, .04),
                "agents_present"    : maybe_null(sp, .04),
            })

    df = pd.DataFrame(rows)
    nd = int(len(df) * .02)
    df = pd.concat([df, df.sample(n=nd, random_state=SEED)], ignore_index=True)\
           .sample(frac=1, random_state=SEED).reset_index(drop=True)

    # Inject negative adherence
    neg = np.random.random(len(df)) < 0.01
    df.loc[neg, "adherence_%"] = df.loc[neg, "adherence_%"].apply(
        lambda x: -abs(float(x)) if pd.notna(x) else x)

    print(f"   ✓ {len(df):,} rows, {len(df.columns)} cols")
    return df

# ── MAIN ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60)
    print("  NovaBridge Solutions — Dirty Dataset Generator v2")
    print("=" * 60)

    df1 = gen_interaction(1_000_000)
    df1.to_csv("interaction_file.csv", index=False)
    print(f"   → Saved interaction_file.csv\n")

    df2 = gen_performance()
    df2.to_csv("performance_file.csv", index=False)
    print(f"   → Saved performance_file.csv\n")

    iids = df1["interaction_id"].dropna().tolist()
    df3  = gen_survey(iids, 205_000)
    df3.to_csv("survey_report.csv", index=False)
    print(f"   → Saved survey_report.csv\n")

    df4 = gen_schedule()
    df4.to_csv("schedule_adherence_file.csv", index=False)
    print(f"   → Saved schedule_adherence_file.csv\n")

    print("=" * 60)
    print("  ✅ All 4 files generated!")
    print("\n📊 QA SUMMARY")
    for nm, df in [("interaction_file", df1), ("performance_file", df2),
                   ("survey_report",    df3), ("schedule_adherence", df4)]:
        print(f"  {nm:<25} rows={len(df):>8,}  null%="
              f"{df.isnull().mean().mean()*100:.1f}%")