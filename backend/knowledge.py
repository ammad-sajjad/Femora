"""A small trusted-source library for the companion (retrieval before answering).

Each topic is a short summary, written in our own words, of the public guidance on the page it cites (NHS, WHO, MedlinePlus;
every URL was checked on 25 Sep 2026). The companion is given the best-matching topics for each question and told to base
its answer on them, and the app shows the sources under the answer.

Matching is deliberately simple and explainable: keyword and phrase hits in English, Roman Urdu and Urdu script, weighted
by how specific the keyword is. No embeddings, no external service.
"""
import re
from dataclasses import dataclass


@dataclass(frozen=True)
class Topic:
    id: str
    title: str
    source: str  # organisation and page title, shown to the user
    url: str
    keywords: tuple[str, ...]
    text: str


TOPICS: list[Topic] = [
    Topic("period_pain", "Period pain", "NHS: Period pain", "https://www.nhs.uk/symptoms/period-pain/",
          ("period pain", "cramps", "cramp", "painful period", "dysmenorrhea", "dysmenorrhoea", "pain during period", "stomach pain period",
           "lower belly pain", "pait dard", "pet dard", "pait mein dard", "haiz dard", "mahwari dard", "periods mein dard", "dard periods",
           "پیٹ درد", "پیٹ میں درد", "ماہواری درد", "ماہواری میں درد", "حیض", "مروڑ"),
          "Period pain is common and usually comes from the womb muscle tightening (driven by prostaglandins). It is often a cramp in the "
          "lower tummy that can spread to the back and thighs, starting when bleeding starts and lasting 1 to 3 days. Helpful at home: a "
          "heat pad or hot water bottle on the tummy, a warm bath, light exercise such as walking or gentle yoga, and gentle tummy massage. "
          "Ibuprofen (an anti-inflammatory) works well because it lowers prostaglandins; paracetamol is an alternative. Pain that is new, "
          "severe, not helped by painkillers, happens outside periods or during sex, or comes with fever or unusual discharge can be caused by "
          "conditions such as endometriosis, fibroids or pelvic infection and should be checked by a doctor."),
    Topic("heavy_periods", "Heavy periods", "NHS: Heavy periods", "https://www.nhs.uk/conditions/heavy-periods/",
          ("heavy period", "heavy bleeding", "heavy flow", "clots", "flooding", "changing pad every hour", "zyada khoon", "bohat khoon",
           "bahut khoon", "zyada bleeding", "بہت خون", "زیادہ خون", "لوتھڑے"),
          "A period is considered heavy when it affects daily life: changing a pad or tampon every 1 to 2 hours, needing to use two at once, "
          "passing clots larger than about 2.5 cm, bleeding through clothes or bedding, or bleeding for more than 7 days. Common causes include "
          "hormone changes (often in teenagers and near menopause), fibroids, polyps, endometriosis, PMOS (PCOS) and some contraceptive coils. "
          "Heavy periods can lead to iron-deficiency anaemia, which causes tiredness and breathlessness. A doctor can check for causes and "
          "offer effective treatments (for example tranexamic acid, hormonal options or an IUS). Bleeding so heavy that you feel faint, dizzy "
          "or are soaking a pad every hour for several hours needs urgent care."),
    Topic("pcos", "PMOS (formerly PCOS)", "NHS: Polyendocrine metabolic ovarian syndrome (PMOS)",
          "https://www.nhs.uk/conditions/polyendocrine-metabolic-ovarian-syndrome-pmos/",
          ("pcos", "pcod", "pmos", "polycystic", "cysts on ovaries", "ovarian cysts pcos", "insulin resistance", "facial hair pcos",
           "pcos diet", "pcos weight", "پی سی او ایس", "پولی سسٹک"),
          "PMOS, the new name the NHS uses for polycystic ovary syndrome (PCOS), is a common hormone condition. Signs include irregular or "
          "missing periods, extra hair on the face or body, acne or oily skin, hair thinning, weight gain or difficulty losing weight, dark "
          "velvety skin patches on the neck or armpits, low mood and difficulty getting pregnant. It is diagnosed by a doctor using the history, "
          "blood tests (hormones, insulin resistance) and sometimes an ultrasound. There is no cure, but it is very manageable: losing even 5 to "
          "10% of body weight if overweight, regular physical activity and a diet with fewer refined carbohydrates and sugary drinks can make "
          "periods more regular and improve symptoms. Doctors may use the pill or an IUS for periods, metformin, and treatments for hair growth "
          "or fertility. Long-term it raises the risk of type 2 diabetes, so regular checks are sensible."),
    Topic("irregular_periods", "Irregular periods", "NHS: Irregular periods", "https://www.nhs.uk/symptoms/irregular-periods/",
          ("irregular period", "irregular cycle", "periods not regular", "cycle changes", "periods come early", "periods come late",
           "periods be qaida", "bay qaida", "be tarteeb", "بے قاعدہ", "بےقاعدہ", "ماہواری بے قاعدہ"),
          "A normal cycle is usually 21 to 35 days, and it is common for it to vary by a few days. Periods are called irregular when the length "
          "between them keeps changing a lot. Common reasons are puberty and the years before menopause, stress, big weight changes, intense "
          "exercise, some contraceptives, PMOS (PCOS), thyroid problems and pregnancy. Tracking your cycle helps a doctor see the pattern. See a "
          "doctor if periods suddenly become irregular, if cycles are shorter than 21 or longer than 35 days, if they vary by more than about "
          "20 days, or if you are trying to get pregnant."),
    Topic("missed_period", "Missed or late period", "NHS: Missed or late periods", "https://www.nhs.uk/symptoms/missed-or-late-periods/",
          ("missed period", "late period", "period is late", "periods are late", "no period", "period not come", "period didnt come", "period hasn't come", "delayed period",
           "periods nahi aaye", "period nahi aya", "mahwari nahi", "ماہواری نہیں", "پیریڈ نہیں", "تاخیر"),
          "A period can be late or missed because of pregnancy, stress, sudden weight loss or gain, very intense exercise, PMOS (PCOS), "
          "thyroid problems, breastfeeding, some contraceptives, or the approach of menopause. If there is any chance of pregnancy, a home "
          "pregnancy test is the first step; it is most reliable from the first day of the missed period. See a doctor if you have missed "
          "three periods in a row and are not pregnant, if periods stop before 45, or if you have bleeding after menopause."),
    Topic("pms", "PMS", "NHS: Pre-menstrual syndrome (PMS)", "https://www.nhs.uk/conditions/pre-menstrual-syndrome/",
          ("pms", "premenstrual", "pre menstrual", "mood swings before period", "irritable before period", "bloating before period",
           "breast tender before period", "period se pehle", "پیریڈ سے پہلے", "ماہواری سے پہلے"),
          "PMS is the physical and emotional symptoms many women get in the 2 weeks before a period: mood swings, irritability, anxiety, "
          "tiredness, bloating, breast tenderness, headaches, spots and trouble sleeping. Symptoms ease once the period starts. Helpful: regular "
          "exercise, enough sleep, smaller more frequent meals, less salt, caffeine and alcohol, and stress-relief such as yoga. Painkillers such "
          "as ibuprofen or paracetamol can help pain. Keeping a symptom diary for 2 to 3 cycles helps. If symptoms are severe or affect daily "
          "life (including very low mood), a doctor can offer treatment."),
    Topic("endometriosis", "Endometriosis", "NHS: Endometriosis", "https://www.nhs.uk/conditions/endometriosis/",
          ("endometriosis", "pain during sex", "painful sex", "pain when pooping during period", "pelvic pain every month",
           "severe period pain", "infertility pain"),
          "Endometriosis is when tissue like the womb lining grows elsewhere, such as on the ovaries. Typical signs are period pain that stops "
          "you doing normal activities, pain during or after sex, pain when peeing or pooing during a period, pelvic pain between periods, and "
          "difficulty getting pregnant. It often takes years to be diagnosed, so keeping a pain diary helps. Painkillers and hormonal treatments "
          "can control symptoms, and surgery is an option. See a doctor if you have these symptoms, especially if they affect daily life."),
    Topic("uti", "Urine infection (UTI)", "NHS: Urinary tract infections (UTIs)", "https://www.nhs.uk/conditions/urinary-tract-infections-utis/",
          ("uti", "urine infection", "burning urine", "burning when peeing", "when i pee", "burning when i pee", "pee often", "peeing", "pain when urinating", "cystitis", "frequent urination",
           "peshab mein jalan", "peshab jalan", "jalan peshab", "پیشاب میں جلن", "پیشاب جلن", "بار بار پیشاب"),
          "Urine infections are common in women. Signs are burning or pain when peeing, needing to pee often or urgently, cloudy or "
          "smelly urine, lower tummy pain, and sometimes blood in the urine. Drinking plenty of water and taking paracetamol for pain can "
          "help. Mild infections sometimes clear on their own, but many need antibiotics from a doctor. See a doctor the same day if you are "
          "pregnant, have a fever, pain in your back or side, feel sick or shivery, or have blood in your urine, because the infection may "
          "have reached the kidneys. Antibiotics should only be taken when prescribed."),
    Topic("discharge", "Vaginal discharge", "NHS: Vaginal discharge", "https://www.nhs.uk/symptoms/vaginal-discharge/",
          ("discharge", "white discharge", "leucorrhoea", "leukorrhea", "safed pani", "safaid pani", "likoria", "sailan", "سفید پانی",
           "لیکوریا", "رطوبت", "اخراج"),
          "Some vaginal discharge is normal and healthy. It changes through the cycle: thin and clear, slippery around ovulation, and "
          "thicker at other times. See a doctor or pharmacist if it changes in colour (green, yellow or grey), smell (fishy or unpleasant) "
          "or texture (like cottage cheese), or comes with itching, soreness, pain, bleeding between periods or pain when peeing. Common "
          "causes are thrush and bacterial vaginosis, which are easily treated; some sexually transmitted infections cause it too. Avoid "
          "douching and perfumed soaps, which upset the natural balance."),
    Topic("thrush", "Vaginal thrush (yeast infection)", "NHS: Thrush", "https://www.nhs.uk/conditions/thrush-in-men-and-women/",
          ("thrush", "yeast infection", "fungal infection", "cottage cheese", "itching down there", "vaginal itching", "itchy vagina", "cottage cheese discharge",
           "kharish", "khujli", "خارش", "کھجلی"),
          "Thrush is a common yeast infection. Signs are itching and soreness around the vagina, white discharge that often looks like "
          "cottage cheese and does not smell, and stinging when peeing. It is not sexually transmitted. It can be treated with antifungal "
          "pessaries or cream from a pharmacy (such as clotrimazole). See a doctor instead of self-treating if it is the first time, if you "
          "are pregnant or breastfeeding, under 16 or over 60, if it keeps coming back (more than twice in 6 months), or if treatment has not "
          "worked. Loose cotton underwear and avoiding perfumed products can help prevent it."),
    Topic("bv", "Bacterial vaginosis", "NHS: Bacterial vaginosis", "https://www.nhs.uk/conditions/bacterial-vaginosis/",
          ("bacterial vaginosis", "bv", "fishy smell", "bad smell discharge", "badboo", "bad smell", "بدبو"),
          "Bacterial vaginosis (BV) is a common change in the natural bacteria of the vagina. The main sign is a thin white or grey discharge "
          "with a strong fishy smell, often stronger after sex. It is not a sexually transmitted infection, but it is more common in sexually "
          "active women. It is treated with antibiotic tablets or gel, so see a doctor or sexual health clinic; this is especially important "
          "in pregnancy. Avoiding douching and perfumed soaps lowers the chance of it coming back."),
    Topic("breast_lump", "Breast lump", "NHS: Breast lump", "https://www.nhs.uk/symptoms/breast-lump/",
          ("breast lump", "lump in breast", "lump in my breast", "breast gaanth", "chhati mein gaanth", "armpit lump", "gilti", "گلٹی",
           "چھاتی میں گانٹھ", "گانٹھ"),
          "Most breast lumps are not cancer. Common harmless causes are cysts (fluid-filled), fibroadenomas (smooth, rubbery, move easily, "
          "common in younger women) and normal lumpiness that changes with the cycle. But any new lump should be checked by a doctor, ideally "
          "within about two weeks, because only an examination and usually an ultrasound or mammogram can tell. Also see a doctor for a lump in "
          "the armpit, a change in breast size or shape, skin dimpling or redness, a nipple that turns inward, a rash on the nipple, or discharge "
          "(especially bloody) from the nipple."),
    Topic("breast_pain", "Breast pain", "NHS: Breast pain", "https://www.nhs.uk/symptoms/breast-pain/",
          ("breast pain", "sore breasts", "tender breasts", "breast tenderness", "chhati mein dard", "چھاتی میں درد"),
          "Breast pain is very common and on its own is rarely a sign of cancer. Pain that comes and goes with the cycle, often in both "
          "breasts in the week before a period, is caused by normal hormone changes. It can also come from pregnancy, breastfeeding, a "
          "poorly fitting bra, a strained chest muscle, or some medicines. A well-fitted supportive bra (including at night), and paracetamol "
          "or ibuprofen can help. See a doctor if the pain is in one spot and does not go away after your next period, if there is a lump, "
          "redness, warmth or swelling, or if you have a fever."),
    Topic("self_exam", "Checking your breasts", "NHS: How to check your breasts", "https://www.nhs.uk/tests-and-treatments/how-to-check-your-breasts-or-chest/",
          ("self exam", "self-exam", "check my breasts", "how to check breasts", "breast exam", "breast self examination", "خود معائنہ"),
          "There is no special technique; the aim is to know what is normal for you. Look at and feel your breasts regularly, including up "
          "to the collarbone and into the armpits, in front of a mirror with arms down and then raised, and lying down. A good time is a few "
          "days after your period ends, when breasts are least lumpy. Look for changes: a new lump or thickening, change in size or shape, "
          "skin puckering or dimpling, a rash or crusting on the nipple, the nipple pulling in, discharge, or constant pain in one place. "
          "Report any change to a doctor."),
    Topic("anaemia", "Iron-deficiency anaemia", "NHS: Iron deficiency anaemia", "https://www.nhs.uk/conditions/iron-deficiency-anaemia/",
          ("anaemia", "anemia", "low iron", "low haemoglobin", "low hemoglobin", "low hb", "iron deficiency", "always tired", "weak and tired",
           "khoon ki kami", "kamzori", "خون کی کمی", "کمزوری", "تھکاوٹ"),
          "Iron-deficiency anaemia is very common in women, often because of heavy periods, pregnancy or a diet low in iron. It causes "
          "tiredness, lack of energy, shortness of breath, a pounding heartbeat, pale skin and headaches. A simple blood test (haemoglobin "
          "and ferritin) confirms it. Iron-rich foods help: red meat, liver, beans and lentils (daal), chickpeas, green leafy vegetables, "
          "dried fruit and fortified cereals; vitamin C (fruit, lemon) helps absorption, while tea with meals reduces it. Iron tablets work "
          "but should be started after a blood test, because the cause needs finding and too much iron is harmful. They can cause "
          "constipation or dark stools."),
    Topic("menopause", "Menopause and perimenopause", "NHS: Menopause and perimenopause",
          "https://www.nhs.uk/conditions/menopause-and-perimenopause/",
          ("menopause", "perimenopause", "hot flushes", "hot flashes", "night sweats", "periods stopping", "mahwari band", "سن یاس",
           "ماہواری بند"),
          "Menopause is when periods stop for 12 months, usually between 45 and 55. In the years before (perimenopause), periods become "
          "irregular and symptoms can start: hot flushes, night sweats, trouble sleeping, low mood or anxiety, brain fog, vaginal dryness and "
          "joint aches. Regular exercise, a healthy weight, less caffeine and alcohol, layered clothing and a cool bedroom help. Hormone "
          "replacement therapy (HRT) is an effective treatment a doctor can discuss. Any bleeding after menopause should always be checked by "
          "a doctor."),
    Topic("headache", "Headaches and migraine", "NHS: Headaches", "https://www.nhs.uk/symptoms/headaches/",
          ("headache", "migraine", "head pain", "sir dard", "sar dard", "sar mein dard", "sir mein dard", "سر درد", "سر میں درد", "درد شقیقہ"),
          "Most headaches are not serious and ease with rest, fluids, regular meals, less screen time and paracetamol or ibuprofen. Some "
          "women get migraines around their period, linked to the fall in oestrogen; a headache diary helps spot this. Using painkillers on "
          "more than about 15 days a month can itself cause headaches. Get urgent help for a sudden very severe headache, a headache with a "
          "stiff neck, fever or rash, after a head injury, with weakness, confusion or problems speaking or seeing, or a severe headache with "
          "swelling or vision changes in pregnancy."),
    Topic("acne", "Acne", "NHS: Acne", "https://www.nhs.uk/conditions/acne/",
          ("acne", "pimples", "spots", "breakouts", "daane", "danay", "keel", "مہاسے", "دانے", "کیل"),
          "Acne is common and often flares before periods because of hormone changes; hormonal acne on the chin and jaw can also be a sign of "
          "PMOS (PCOS). Wash the face twice a day with a mild cleanser, do not squeeze spots (it causes scarring), and use non-oily "
          "(non-comedogenic) products. Pharmacy gels with benzoyl peroxide help mild acne; they can dry the skin and bleach fabric. Treatments "
          "take 6 to 8 weeks to work. See a doctor for acne that is moderate or severe, leaves scars, or affects your mood; prescription "
          "options work well."),
    Topic("hirsutism", "Excess hair growth", "NHS: Hirsutism", "https://www.nhs.uk/symptoms/hirsutism/",
          ("excess hair", "facial hair", "hair on chin", "unwanted hair", "hirsutism", "chehre par baal", "baal", "چہرے پر بال", "غیر ضروری بال"),
          "Excess dark, thick hair on the face, chest, tummy or back (hirsutism) is often caused by higher levels of male-type hormones, and "
          "PMOS (PCOS) is the most common cause. It can also run in families. Losing weight if overweight can reduce it. Hair removal "
          "(shaving, waxing, threading, creams, laser) manages it, and a doctor can prescribe treatments such as certain contraceptive pills or "
          "creams. See a doctor if it starts suddenly or comes with a deeper voice or irregular periods, so the cause can be checked."),
    Topic("hair_loss", "Hair loss", "NHS: Hair loss", "https://www.nhs.uk/symptoms/hair-loss/",
          ("hair loss", "hair fall", "hair thinning", "losing hair", "baal girna", "baal gir", "بال گرنا", "بال گر"),
          "Losing up to around 100 hairs a day is normal. Temporary heavy shedding often follows stress, illness, childbirth, crash dieting "
          "or low iron, and usually recovers within months. Thinning at the top of the head can be linked to hormones, including PMOS "
          "(PCOS), or thyroid problems. A doctor can check iron, thyroid and hormones with blood tests. See a doctor if hair loss is sudden, "
          "in patches, or comes with other symptoms."),
    Topic("thyroid", "Underactive thyroid", "NHS: Underactive thyroid", "https://www.nhs.uk/conditions/underactive-thyroid-hypothyroidism/",
          ("thyroid", "hypothyroid", "tsh", "underactive thyroid", "تھائیرائیڈ"),
          "An underactive thyroid is more common in women. Signs develop slowly: tiredness, weight gain, feeling cold, constipation, dry skin, "
          "hair thinning, low mood, and heavier or irregular periods. A blood test (TSH) diagnoses it, and daily thyroid hormone tablets treat "
          "it well. It matters when trying for a baby, so women with symptoms or a family history should ask for a test."),
    Topic("heartburn", "Heartburn and acidity", "NHS: Heartburn and acid reflux", "https://www.nhs.uk/conditions/heartburn-and-acid-reflux/",
          ("heartburn", "acidity", "acid reflux", "indigestion", "burning chest after eating", "gas", "tezabiyat", "tezabiat", "seene mein jalan",
           "تیزابیت", "سینے میں جلن", "بدہضمی"),
          "Heartburn is a burning feeling in the chest from stomach acid, often after eating, when lying down or bending. It is common in "
          "pregnancy. Helpful: smaller meals, not eating 3 to 4 hours before bed, raising the head of the bed, and cutting down spicy, fatty "
          "or fried food, tea and coffee, fizzy drinks and smoking. Antacids from a pharmacy relieve it quickly. See a doctor if it happens "
          "most days for 3 weeks or more, or with difficulty swallowing, weight loss or vomiting. Chest pain that spreads to the arm, jaw "
          "or back, or comes with breathlessness, needs emergency care."),
    Topic("constipation", "Constipation", "NHS: Constipation", "https://www.nhs.uk/conditions/constipation/",
          ("constipation", "hard stool", "can't poop", "qabz", "qabz ho", "قبض"),
          "Constipation is common, including around periods and in pregnancy. Helpful: more fibre (fruit, vegetables, whole grains, daal), "
          "plenty of water, regular activity, and not delaying when you need to go. A bulk-forming fibre supplement such as ispaghula husk "
          "(isabgol) from a pharmacy helps, taken with plenty of water. See a doctor if it lasts more than 2 weeks despite this, or with blood "
          "in the stool, weight loss, severe tummy pain or a lasting change in bowel habit."),
    Topic("diarrhoea", "Diarrhoea and vomiting", "NHS: Diarrhoea and vomiting", "https://www.nhs.uk/symptoms/diarrhoea-and-vomiting/",
          ("diarrhoea", "diarrhea", "loose motion", "loose motions", "vomiting", "dast", "ulti", "دست", "الٹی", "اسہال"),
          "Diarrhoea and vomiting usually get better within a few days. The main risk is dehydration: sip fluids often, and oral rehydration "
          "solution (ORS) replaces lost salts. Eat when you feel able. Get medical help if you cannot keep fluids down, have signs of "
          "dehydration (very little dark urine, dizziness), blood in diarrhoea or vomit, severe tummy pain, a high fever, or symptoms lasting "
          "more than a few days; seek care sooner if pregnant."),
    Topic("bloating", "Bloating", "NHS: Bloating", "https://www.nhs.uk/symptoms/bloating/",
          ("bloating", "bloated", "swollen tummy", "pait phoolna", "pet phoolna", "پیٹ پھولنا", "اپھارہ"),
          "Bloating is very common before periods and with constipation or trapped wind. Helpful: regular exercise, eating slowly, smaller "
          "meals, less fizzy drinks, and treating constipation. See a doctor if bloating is persistent (most days for 3 weeks or more), "
          "especially over 50, or with feeling full quickly, weight loss, bleeding or a change in bowel habit, because rarely it can be a sign "
          "of an ovarian problem."),
    Topic("pregnancy_signs", "Early signs of pregnancy", "NHS: Signs and symptoms of pregnancy",
          "https://www.nhs.uk/pregnancy/trying-for-a-baby/signs-and-symptoms-that-might-mean-youre-pregnant/",
          ("am i pregnant", "pregnancy test", "signs of pregnancy", "could i be pregnant", "pregnant", "hamla", "hamila", "umeed se",
           "حاملہ", "حمل", "امید سے"),
          "The earliest sign is usually a missed period. Others are feeling sick (at any time of day), sore or tender breasts, tiredness, "
          "needing to pee more often, a metallic taste and food cravings or dislikes. Some women have light spotting around the time the "
          "period was due. A home pregnancy test is accurate from the first day of the missed period. If positive, see a doctor or midwife "
          "early, start folic acid (400 micrograms daily) if not already taking it, and check any medicines with a pharmacist. Get urgent help "
          "for heavy bleeding, severe one-sided tummy pain, or pain in the shoulder tip, which can be signs of an ectopic pregnancy."),
    Topic("morning_sickness", "Nausea in pregnancy", "NHS: Vomiting and morning sickness",
          "https://www.nhs.uk/pregnancy/common-symptoms/vomiting-and-morning-sickness/",
          ("morning sickness", "nausea pregnancy", "vomiting pregnancy", "feel sick pregnant", "ji matlana", "matli", "متلی", "جی متلانا"),
          "Nausea and vomiting are common in early pregnancy and usually ease by 16 to 20 weeks. Helpful: rest, small frequent plain meals "
          "(dry crackers before getting up), cold drinks sipped often, and foods or drinks with ginger. See a doctor urgently if you cannot keep "
          "any food or drink down for 24 hours, have very dark urine or none for 8 hours, feel very weak or dizzy, have tummy pain or a fever, "
          "or vomit blood. This can be hyperemesis gravidarum, which is treatable."),
    Topic("fertility", "Trying for a baby and the fertile window", "NHS: Trying for a baby", "https://www.nhs.uk/pregnancy/trying-for-a-baby/",
          ("fertile", "fertile window", "ovulation", "trying to conceive", "trying for a baby", "get pregnant", "conceive", "bacha", "aulad",
           "اولاد", "بچہ", "حمل ٹھہرنا", "بیضہ"),
          "Ovulation usually happens about 12 to 16 days before the next period, and the most fertile days are the 5 days before ovulation "
          "and the day of it. Having sex every 2 to 3 days through the cycle gives the best chance without needing to time it. Start folic "
          "acid (400 micrograms daily) before trying, keep a healthy weight, stop smoking and limit alcohol and caffeine. About 8 in 10 couples "
          "conceive within a year. See a doctor if it has not happened after a year of trying (or 6 months if you are over 35), or sooner if "
          "periods are irregular or absent."),
    Topic("stress_mood", "Stress, anxiety and low mood", "NHS: Mental health", "https://www.nhs.uk/mental-health/",
          ("stress", "stressed", "anxiety", "anxious", "depressed", "depression", "low mood", "sad", "panic", "pareshan", "pareshani", "udaas",
           "ghabrahat", "tension", "پریشان", "اداس", "گھبراہٹ", "ذہنی دباؤ"),
          "Stress, anxiety and low mood are common and can affect periods, sleep and appetite. Helpful everyday steps: regular physical "
          "activity, a steady sleep routine, talking to someone you trust, breathing exercises, limiting caffeine, and time for things you "
          "enjoy. Mood can dip before periods (PMS). See a doctor or mental-health professional if low mood or anxiety lasts more than two "
          "weeks, affects daily life, or you have thoughts of harming yourself; if you might act on those thoughts, get emergency help now "
          "(Rescue 1122 in Pakistan)."),
    Topic("sleep", "Sleep problems", "NHS: Insomnia", "https://www.nhs.uk/conditions/insomnia/",
          ("insomnia", "can't sleep", "cannot sleep", "poor sleep", "sleep problems", "neend nahi", "neend", "نیند نہیں", "بے خوابی"),
          "Most adults need 7 to 9 hours of sleep. Helpful habits: fixed times for going to bed and getting up, a dark, quiet, cool bedroom, "
          "no screens for an hour before bed, regular exercise earlier in the day, and avoiding caffeine after lunch and heavy meals late at "
          "night. Sleep can be worse before periods and around menopause. See a doctor if poor sleep lasts for months and affects daily "
          "life; talking therapy for insomnia (CBT-I) works well."),
    Topic("healthy_weight", "Healthy weight and diet", "WHO: Healthy diet", "https://www.who.int/news-room/fact-sheets/detail/healthy-diet",
          ("lose weight", "weight loss", "diet", "healthy diet", "overweight", "wazan kam", "motapa", "وزن کم", "موٹاپا", "غذا"),
          "A healthy diet is mostly vegetables, fruit, whole grains, pulses (daal, chickpeas) and nuts, with less sugar, salt and fat "
          "(especially fried food and ghee-heavy dishes) and few sugary drinks. At least 150 minutes a week of moderate activity, such as brisk "
          "walking, is recommended. Slow, steady weight loss of about 0.5 to 1 kg a week is safest and easier to keep off than crash diets. "
          "For women with PMOS (PCOS), losing 5 to 10% of body weight can make periods more regular."),
    Topic("ovarian_cyst", "Ovarian cysts", "NHS: Ovarian cyst", "https://www.nhs.uk/conditions/ovarian-cyst/",
          ("ovarian cyst", "cyst on ovary", "ovary cyst", "rasoli", "رسولی", "سسٹ"),
          "Ovarian cysts are fluid-filled sacs that are very common and usually harmless; many form as part of the normal cycle and disappear "
          "within a few months without treatment. Most cause no symptoms, but larger ones can cause pelvic pain, bloating, pain during sex or "
          "changes to periods. They are different from the many small follicles seen in PMOS (PCOS). Get urgent help for sudden severe pelvic "
          "pain, especially with fever or vomiting, as a cyst can burst or twist."),
    Topic("fibroids", "Fibroids", "NHS: Fibroids", "https://www.nhs.uk/conditions/fibroids/",
          ("fibroid", "fibroids", "uterine fibroids", "rasoli bachedani", "بچہ دانی کی رسولی"),
          "Fibroids are non-cancerous growths in or around the womb, common in women over 30. Many cause no symptoms. Others cause heavy or "
          "painful periods, tummy pain or swelling, needing to pee often, constipation or pain during sex. An ultrasound finds them. Treatment "
          "is only needed if they cause problems, and ranges from medicines for heavy bleeding to procedures to shrink or remove them."),
    Topic("contraception", "Contraception", "NHS: Contraception", "https://www.nhs.uk/contraception/",
          ("contraception", "birth control", "the pill", "family planning", "condom", "iud", "coil", "khandani mansooba bandi",
           "خاندانی منصوبہ بندی", "مانع حمل"),
          "There are many methods, including long-acting options (implant, injection, copper coil, hormonal IUS) that are over 99% effective, "
          "pills, and condoms, which also protect against sexually transmitted infections. The best choice depends on health, age, whether "
          "you smoke, and plans for pregnancy, so a doctor, lady health visitor or family planning clinic can help choose. Some methods change "
          "periods: lighter, irregular or none."),
    Topic("cervical_screening", "Cervical screening", "NHS: Cervical screening", "https://www.nhs.uk/tests-and-treatments/cervical-screening/",
          ("pap smear", "pap test", "cervical screening", "cervical cancer", "hpv", "سروائیکل"),
          "Cervical screening (a smear or HPV test) checks the cervix for the high-risk HPV virus and early cell changes, so they can be "
          "treated before cancer develops. It is recommended regularly from the mid-20s (every 3 to 5 years depending on age). The HPV "
          "vaccine also protects. See a doctor for bleeding after sex, between periods or after menopause, or unusual discharge, even if a "
          "recent test was normal."),
]

_WORD = re.compile(r"[\w'؀-ۿ]+")


def _norm(text: str) -> str:
    return " " + " ".join(_WORD.findall(text.lower().replace("’", "'"))) + " "


# The condition's own name counts most (it says exactly what she asks about), then multi-word phrases, then single words
CORE = {"pcos", "pcod", "pmos", "polycystic", "uti", "cystitis", "thrush", "yeast infection", "cottage cheese", "bacterial vaginosis",
        "endometriosis", "menopause", "perimenopause", "anaemia", "anemia", "thyroid", "fibroid", "fibroids", "ovarian cyst", "pms",
        "migraine", "morning sickness", "hirsutism", "insomnia", "self exam", "self-exam", "breast lump", "heavy period", "late period",
        "missed period", "period is late", "fertile window", "pap smear", "contraception", "likoria", "leucorrhoea", "safed pani"}


def _weight(keyword: str) -> float:
    if keyword in CORE:
        return 3.0
    return 1.0 + 0.8 * (len(keyword.split()) - 1)


def search(query: str, limit: int = 2, min_score: float = 1.0) -> list[Topic]:
    """The best-matching topics for a question (possibly several turns joined)."""
    q = _norm(query)
    scored = []
    for t in TOPICS:
        s = sum(_weight(k) for k in t.keywords if _norm(k) in q)
        if s >= min_score:
            scored.append((s, t))
    scored.sort(key=lambda x: -x[0])
    return [t for _, t in scored[:limit]]


def prompt_block(topics: list[Topic]) -> str:
    """The retrieved passages as they are given to the model."""
    parts = [f"[{i + 1}] {t.title} ({t.source})\n{t.text}" for i, t in enumerate(topics)]
    return "\n\n".join(parts)
