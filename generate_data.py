import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta

random.seed(42)
np.random.seed(42)

regions = ["North", "South", "East", "West", "Central"]
segments = ["Consumer", "Corporate", "Home Office"]
first_names = ["Aarav","Vivaan","Aditya","Vihaan","Arjun","Sai","Reyansh","Ayaan","Krishna","Ishaan",
               "Ananya","Diya","Priya","Isha","Anika","Riya","Kavya","Aadhya","Myra","Saanvi",
               "James","Mary","John","Patricia","Robert","Jennifer","Michael","Linda","David","Elizabeth"]
last_names = ["Sharma","Verma","Gupta","Singh","Kumar","Patel","Reddy","Mehta","Nair","Iyer",
              "Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez"]

n_customers = 150
customers = []
for cid in range(1, n_customers + 1):
    name = f"{random.choice(first_names)} {random.choice(last_names)}"
    region = random.choice(regions)
    segment = random.choices(segments, weights=[0.55, 0.30, 0.15])[0]
    signup = datetime(2022, 1, 1) + timedelta(days=random.randint(0, 900))
    customers.append([cid, name, region, segment, signup.date().isoformat()])

customers_df = pd.DataFrame(customers, columns=["customer_id","customer_name","region","segment","signup_date"])

categories = {
    "Electronics": ["Wireless Mouse","Bluetooth Speaker","USB-C Hub","Laptop Stand","Webcam",
                    "Mechanical Keyboard","Power Bank","Noise Cancelling Headphones","Smart Watch","Monitor Arm"],
    "Office Supplies": ["Notebook Set","Desk Organizer","Sticky Notes Pack","Ballpoint Pens (Box)","Whiteboard",
                        "Stapler","Filing Folders","Printer Paper (Ream)","Desk Lamp","Corkboard"],
    "Furniture": ["Office Chair","Standing Desk","Bookshelf","Filing Cabinet","Desk Mat",
                  "Visitor Chair","Cubicle Partition","Meeting Table","Footrest","Monitor Riser"],
    "Home & Kitchen": ["Coffee Maker","Electric Kettle","Air Fryer","Blender","Vacuum Flask",
                       "Dish Rack","Non-stick Pan Set","Cutlery Set","Storage Containers","Table Lamp"],
}

products = []
pid = 1
base_prices = {"Electronics": (800, 12000), "Office Supplies": (50, 1500),
               "Furniture": (1500, 18000), "Home & Kitchen": (300, 6000)}
for cat, items_ in categories.items():
    lo, hi = base_prices[cat]
    for item in items_:
        price = round(random.uniform(lo, hi), -1)
        cost_ratio = random.uniform(0.55, 0.75)
        products.append([pid, item, cat, price, round(price * cost_ratio, 2)])
        pid += 1

products_df = pd.DataFrame(products, columns=["product_id","product_name","category","unit_price","unit_cost"])

start_date = datetime(2024, 1, 1)
end_date = datetime(2025, 12, 31)
n_orders = 2200

orders = []
order_items = []
oid = 1
item_id = 1
month_weights = {1:0.9,2:0.75,3:0.95,4:0.9,5:0.9,6:0.85,7:0.9,8:0.95,9:1.0,10:1.25,11:1.35,12:1.3}
date_range_days = (end_date - start_date).days
for _ in range(n_orders):
    while True:
        d = start_date + timedelta(days=random.randint(0, date_range_days))
        if random.random() < month_weights[d.month] / 1.35:
            break
    cust = customers_df.sample(1).iloc[0]
    ship_delay = random.randint(1, 7)
    order_date = d
    ship_date = d + timedelta(days=ship_delay)
    orders.append([oid, cust["customer_id"], order_date.date().isoformat(), ship_date.date().isoformat()])

    n_items = random.choices([1,2,3], weights=[0.6,0.3,0.1])[0]
    chosen_products = products_df.sample(n_items)
    for _, prod in chosen_products.iterrows():
        qty = random.randint(1, 6)
        discount = random.choices([0, 0.05, 0.1, 0.15, 0.2], weights=[0.45,0.2,0.15,0.12,0.08])[0]
        order_items.append([item_id, oid, prod["product_id"], qty, discount])
        item_id += 1
    oid += 1

orders_df = pd.DataFrame(orders, columns=["order_id","customer_id","order_date","ship_date"])
order_items_df = pd.DataFrame(order_items, columns=["order_item_id","order_id","product_id","quantity","discount"])

customers_df.to_csv("data/customers.csv", index=False)
products_df.to_csv("data/products.csv", index=False)
orders_df.to_csv("data/orders.csv", index=False)
order_items_df.to_csv("data/order_items.csv", index=False)
print("done", len(customers_df), len(products_df), len(orders_df), len(order_items_df))
