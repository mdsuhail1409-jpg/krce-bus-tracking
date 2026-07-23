"""
KRCE Bus Tracking System — Database module.
MongoDB Atlas connection, mock database for local dev, seed data.
Moved from the top-level database/db.py to be self-contained within backend.
"""

import uuid
import logging
import bcrypt
import asyncio
from datetime import datetime, timedelta, date
from typing import Dict, List, Optional
from motor.motor_asyncio import AsyncIOMotorClient

from app.config import MONGO_URI, MONGO_DB_NAME

logger = logging.getLogger("KRCE-BUS-DB")

mongo_client: AsyncIOMotorClient = None
db = None


# Utilities for database seeding
def _hash(pw: str) -> str:
    hashed = bcrypt.hashpw(pw.encode('utf-8'), bcrypt.gensalt())
    return hashed.decode('utf-8')


def today() -> str:
    return date.today().isoformat()


def now_str() -> str:
    return datetime.utcnow().isoformat()


def _build_seed():
    users = [
        {"id":"admin01","name":"Admin Krishnamurthy","email":"admin@krce.ac.in","phone":"9840100001","role":"admin","college_id":None,"rfid_card":None,"bus_id":None,"parent_of":None,"licence_no":None,"password_hash":_hash("admin@krce"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"comm01","name":"Dr. Senthil Kumar","email":"committee@krce.ac.in","phone":"9840100002","role":"committee","college_id":"FAC001","rfid_card":None,"bus_id":None,"parent_of":None,"licence_no":None,"password_hash":_hash("comm@krce"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"drv01","name":"Rajan S.","email":"rajan@krce.ac.in","phone":"9840111111","role":"driver","college_id":None,"rfid_card":None,"bus_id":"B01","parent_of":None,"licence_no":"TN-DL-001","password_hash":_hash("driver@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"drv02","name":"Murugan K.","email":"murugan@krce.ac.in","phone":"9840122222","role":"driver","college_id":None,"rfid_card":None,"bus_id":"B02","parent_of":None,"licence_no":"TN-DL-002","password_hash":_hash("driver@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"drv03","name":"Selvam P.","email":"selvam@krce.ac.in","phone":"9840133333","role":"driver","college_id":None,"rfid_card":None,"bus_id":"B03","parent_of":None,"licence_no":"TN-DL-003","password_hash":_hash("driver@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"drv04","name":"Arun M.","email":"arun@krce.ac.in","phone":"9840144444","role":"driver","college_id":None,"rfid_card":None,"bus_id":"B04","parent_of":None,"licence_no":"TN-DL-004","password_hash":_hash("driver@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"drv05","name":"Suresh T.","email":"suresh.d@krce.ac.in","phone":"9840155555","role":"driver","college_id":None,"rfid_card":None,"bus_id":"B05","parent_of":None,"licence_no":"TN-DL-005","password_hash":_hash("driver@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"drv06","name":"Hari Prasad","email":"hari@krce.ac.in","phone":"9840166666","role":"driver","college_id":None,"rfid_card":None,"bus_id":"B06","parent_of":None,"licence_no":"TN-DL-006","password_hash":_hash("driver@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"stu01","name":"Aravind Kumar","email":"aravind@krce.ac.in","phone":"9841100001","role":"student","college_id":"21CS001","rfid_card":"RF001","bus_id":"B01","parent_of":None,"licence_no":None,"password_hash":_hash("student@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"stu02","name":"Priya Devi","email":"priya@krce.ac.in","phone":"9841100002","role":"student","college_id":"21EC002","rfid_card":"RF002","bus_id":"B02","parent_of":None,"licence_no":None,"password_hash":_hash("student@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"stu03","name":"Karthikeyan M","email":"karthik@krce.ac.in","phone":"9841100003","role":"student","college_id":"21ME003","rfid_card":"RF003","bus_id":"B03","parent_of":None,"licence_no":None,"password_hash":_hash("student@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"stu04","name":"Nandhini R","email":"nandhini@krce.ac.in","phone":"9841100004","role":"student","college_id":"21CS004","rfid_card":"RF004","bus_id":"B01","parent_of":None,"licence_no":None,"password_hash":_hash("student@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"stu05","name":"Anitha S","email":"anitha@krce.ac.in","phone":"9841100005","role":"student","college_id":"21IT006","rfid_card":"RF005","bus_id":"B04","parent_of":None,"licence_no":None,"password_hash":_hash("student@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"stu06","name":"Ravi Shankar","email":"ravi@krce.ac.in","phone":"9841100006","role":"student","college_id":"22CS007","rfid_card":"RF006","bus_id":"B05","parent_of":None,"licence_no":None,"password_hash":_hash("student@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"stu07","name":"Meena P","email":"meena@krce.ac.in","phone":"9841100007","role":"student","college_id":"22EC008","rfid_card":"RF007","bus_id":"B02","parent_of":None,"licence_no":None,"password_hash":_hash("student@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"stu08","name":"Saran B","email":"saran@krce.ac.in","phone":"9841100008","role":"student","college_id":"22ME010","rfid_card":"RF008","bus_id":"B03","parent_of":None,"licence_no":None,"password_hash":_hash("student@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"fac01","name":"Dr. Radha L","email":"radha@krce.ac.in","phone":"9841200001","role":"staff","college_id":"FAC002","rfid_card":"RF009","bus_id":"B01","parent_of":None,"licence_no":None,"password_hash":_hash("staff@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"fac02","name":"Dr. Senthil Kumar","email":"senthil@krce.ac.in","phone":"9841200002","role":"staff","college_id":"FAC001","rfid_card":"RF010","bus_id":"B02","parent_of":None,"licence_no":None,"password_hash":_hash("staff@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"par01","name":"Suresh Kumar","email":"suresh.p@gmail.com","phone":"9841300001","role":"parent","college_id":None,"rfid_card":None,"bus_id":None,"parent_of":"21CS001","licence_no":None,"password_hash":_hash("parent@123"),"is_active":1,"created_at":now_str(),"last_login":None},
        {"id":"par02","name":"Meenakshi Devi","email":"meenakshi@gmail.com","phone":"9841300002","role":"parent","college_id":None,"rfid_card":None,"bus_id":None,"parent_of":"21EC002","licence_no":None,"password_hash":_hash("parent@123"),"is_active":1,"created_at":now_str(),"last_login":None},
    ]
    buses = [
        {"id":"B01","number":"TN-01","route_name":"Route A — Woraiyur","driver_id":"drv01","capacity":50,"stops":["KRCE Campus","Samayapuram","Woraiyur Bus Stand","Woraiyur Town","Gandhi Market","KRCE Campus"],"is_active":1,"created_at":now_str()},
        {"id":"B02","number":"TN-02","route_name":"Route B — Srirangam","driver_id":"drv02","capacity":45,"stops":["KRCE Campus","Panjappur","Srirangam","Cauvery Bridge","K.K. Nagar","KRCE Campus"],"is_active":1,"created_at":now_str()},
        {"id":"B03","number":"TN-03","route_name":"Route C — Ariyamangalam","driver_id":"drv03","capacity":50,"stops":["KRCE Campus","Thuvakudi","Ariyamangalam","Cantonment","Collector Office","KRCE Campus"],"is_active":1,"created_at":now_str()},
        {"id":"B04","number":"TN-04","route_name":"Route D — Chatram Bus Stand","driver_id":"drv04","capacity":40,"stops":["KRCE Campus","Palakarai","Chatram Bus Stand","Central","Junction","KRCE Campus"],"is_active":1,"created_at":now_str()},
        {"id":"B05","number":"TN-05","route_name":"Route E — Mannarpuram","driver_id":"drv05","capacity":55,"stops":["KRCE Campus","Thillai Nagar","Mannarpuram","Rockfort","Chinthamani","KRCE Campus"],"is_active":1,"created_at":now_str()},
        {"id":"B06","number":"TN-06","route_name":"Chathiram Bus Stand Route","driver_id":"drv06","capacity":50,"stops":["KRCE Campus","Chathiram Bus Stand","Samayapuram","KRCE Campus"],"is_active":1,"created_at":now_str()},
    ]
    td = today()
    alerts = [
        {"id":str(uuid.uuid4())[:8],"title":"Welcome to KRCE Bus Tracker","message":"The new real-time bus tracking system is now live. Your bus location updates every 5 seconds.","alert_type":"info","target_role":"all","target_bus":None,"sent_by":"admin01","sent_at":now_str(),"is_resolved":0},
        {"id":str(uuid.uuid4())[:8],"title":"Route A — Minor Delay","message":"Bus TN-01 is running approximately 10 minutes late due to traffic near Woraiyur Junction.","alert_type":"delay","target_role":"all","target_bus":"B01","sent_by":"admin01","sent_at":now_str(),"is_resolved":0},
    ]
    attendance = [
        {"id":str(uuid.uuid4()),"user_id":"stu01","bus_id":"B01","tap_type":"boarded","tap_time":now_str(),"stop_name":"Woraiyur Bus Stand","lat":10.7905,"lon":78.7047,"date":td},
        {"id":str(uuid.uuid4()),"user_id":"stu04","bus_id":"B01","tap_type":"boarded","tap_time":now_str(),"stop_name":"Samayapuram","lat":10.9310,"lon":78.8130,"date":td},
        {"id":str(uuid.uuid4()),"user_id":"fac01","bus_id":"B01","tap_type":"boarded","tap_time":now_str(),"stop_name":"Woraiyur Bus Stand","lat":10.7905,"lon":78.7047,"date":td},
        {"id":str(uuid.uuid4()),"user_id":"stu02","bus_id":"B02","tap_type":"boarded","tap_time":now_str(),"stop_name":"Srirangam","lat":10.8631,"lon":78.6933,"date":td},
        {"id":str(uuid.uuid4()),"user_id":"stu07","bus_id":"B02","tap_type":"boarded","tap_time":now_str(),"stop_name":"K.K. Nagar","lat":10.8176,"lon":78.6960,"date":td},
        {"id":str(uuid.uuid4()),"user_id":"stu03","bus_id":"B03","tap_type":"boarded","tap_time":now_str(),"stop_name":"Ariyamangalam","lat":10.8280,"lon":78.7380,"date":td},
        {"id":str(uuid.uuid4()),"user_id":"stu08","bus_id":"B03","tap_type":"boarded","tap_time":now_str(),"stop_name":"Thuvakudi","lat":10.8730,"lon":78.7680,"date":td},
        {"id":str(uuid.uuid4()),"user_id":"stu05","bus_id":"B04","tap_type":"boarded","tap_time":now_str(),"stop_name":"Chatram Bus Stand","lat":10.8096,"lon":78.6964,"date":td},
        {"id":str(uuid.uuid4()),"user_id":"stu06","bus_id":"B05","tap_type":"boarded","tap_time":now_str(),"stop_name":"Mannarpuram","lat":10.8182,"lon":78.7030,"date":td},
    ]
    return users, buses, alerts, attendance


class MockCursor:
    def __init__(self, data):
        self._data = data

    def sort(self, *args, **kwargs):
        if args:
            key = args[0]
            if isinstance(key, list):
                sort_key = key[0][0]
                reverse = key[0][1] == -1
            else:
                sort_key = key
                reverse = kwargs.get("direction", 1) == -1
            try:
                self._data = sorted(self._data, key=lambda x: x.get(sort_key) or "", reverse=reverse)
            except Exception:
                pass
        return self

    def limit(self, n):
        self._data = self._data[:n]
        return self

    async def to_list(self, length=None):
        return self._data


class MockCollection:
    def __init__(self, name, db_instance=None):
        self.name = name
        self.db = db_instance
        self.data = []

    async def create_index(self, *args, **kwargs):
        pass

    async def count_documents(self, query):
        count = 0
        for doc in self.data:
            if self._matches(doc, query):
                count += 1
        return count

    async def find_one(self, query, projection=None, sort=None):
        matched = []
        for doc in self.data:
            if self._matches(doc, query):
                matched.append(doc)
        
        if sort:
            for sort_key, direction in (sort if isinstance(sort, list) else [sort]):
                matched = sorted(matched, key=lambda x: x.get(sort_key) or "", reverse=(direction == -1))
        
        if matched:
            return self._project(matched[0], projection)
        return None

    def find(self, query=None, projection=None):
        query = query or {}
        matched = []
        for doc in self.data:
            if self._matches(doc, query):
                matched.append(self._project(doc, projection))
        return MockCursor(matched)

    async def insert_one(self, doc):
        self.data.append(doc)
        return doc

    async def insert_many(self, docs):
        self.data.extend(docs)
        return docs

    async def update_one(self, query, update_doc, upsert=False):
        found = False
        set_fields = update_doc.get("$set", {})
        for doc in self.data:
            if self._matches(doc, query):
                doc.update(set_fields)
                found = True
                break
        if not found and upsert:
            new_doc = query.copy()
            new_doc.update(set_fields)
            self.data.append(new_doc)
        return found

    async def update_many(self, query, update_doc, upsert=False):
        set_fields = update_doc.get("$set", {})
        count = 0
        for doc in self.data:
            if self._matches(doc, query):
                doc.update(set_fields)
                count += 1
        return count

    async def delete_one(self, query):
        for doc in self.data:
            if self._matches(doc, query):
                self.data.remove(doc)
                break

    async def distinct(self, key, query=None):
        query = query or {}
        vals = set()
        for doc in self.data:
            if self._matches(doc, query):
                val = doc.get(key)
                if val is not None:
                    vals.add(val)
        return list(vals)

    def aggregate(self, pipeline):
        current = list(self.data)

        # Check if this is the boarded count query
        if len(pipeline) == 2 and "$match" in pipeline[0] and "$group" in pipeline[1] and pipeline[1]["$group"].get("_id") == "$bus_id":
            match_q = pipeline[0]["$match"]
            matched_records = [d for d in current if self._matches(d, match_q)]
            counts = {}
            for r in matched_records:
                bid = r.get("bus_id")
                counts[bid] = counts.get(bid, 0) + 1
            return MockCursor([{"_id": bid, "cnt": cnt} for bid, cnt in counts.items()])

        # Check if this is the admin attendance query
        is_admin_attendance = False
        for stage in pipeline:
            if "$lookup" in stage and stage["$lookup"].get("from") == "users":
                is_admin_attendance = True
                break

        if is_admin_attendance:
            match_stage = next((s["$match"] for s in pipeline if "$match" in s), {})
            current = [d for d in current if self._matches(d, match_stage)]

            sort_stage = next((s["$sort"] for s in pipeline if "$sort" in s), None)
            if sort_stage:
                for k, v in sort_stage.items():
                    current = sorted(current, key=lambda x: x.get(k) or "", reverse=(v == -1))

            limit_stage = next((s["$limit"] for s in pipeline if "$limit" in s), 300)
            current = current[:limit_stage]

            projected = []
            for rec in current:
                user = None
                uid = rec.get("user_id")
                if uid and self.db:
                    for u in self.db.users.data:
                        if u.get("id") == uid:
                            user = u
                            break
                bus = None
                bid = rec.get("bus_id")
                if bid and self.db:
                    for b in self.db.buses.data:
                        if b.get("id") == bid:
                            bus = b
                            break

                projected.append({
                    "id": rec.get("id"),
                    "user_id": rec.get("user_id"),
                    "bus_id": rec.get("bus_id"),
                    "tap_type": rec.get("tap_type"),
                    "tap_time": rec.get("tap_time"),
                    "stop_name": rec.get("stop_name"),
                    "lat": rec.get("lat"),
                    "lon": rec.get("lon"),
                    "date": rec.get("date"),
                    "student_name": user.get("name", "Unknown") if user else "Unknown",
                    "college_id": user.get("college_id") if user else None,
                    "bus_number": bus.get("number") if bus else None,
                    "route_name": bus.get("route_name") if bus else None
                })
            return MockCursor(projected)

        for stage in pipeline:
            if "$match" in stage:
                match_query = stage["$match"]
                current = [d for d in current if self._matches(d, match_query)]
            elif "$group" in stage:
                group_stage = stage["$group"]
                group_id = group_stage["_id"]
                if isinstance(group_id, str) and group_id.startswith("$"):
                    field = group_id[1:]
                else:
                    field = group_id

                groups = {}
                for doc in current:
                    val = doc.get(field)
                    if val not in groups:
                        groups[val] = 0
                    groups[val] += 1

                new_current = []
                for val, count in groups.items():
                    new_current.append({"_id": val, "cnt": count, "count": count})
                current = new_current
            elif "$sort" in stage:
                sort_stage = stage["$sort"]
                for sort_field, direction in sort_stage.items():
                    current = sorted(current, key=lambda x: x.get(sort_field) or 0, reverse=(direction == -1))
            elif "$limit" in stage:
                limit_val = stage["$limit"]
                current = current[:limit_val]
        return MockCursor(current)

    def _matches(self, doc, query):
        for k, v in query.items():
            if k == "$or":
                matched_or = False
                for sub_query in v:
                    if self._matches(doc, sub_query):
                        matched_or = True
                        break
                if not matched_or:
                    return False
                continue

            val = doc.get(k)
            if isinstance(v, dict):
                if "$in" in v:
                    if val not in v["$in"]:
                        return False
                elif "$ne" in v:
                    if val == v["$ne"]:
                        return False
                elif "$regex" in v:
                    import re
                    pattern = v["$regex"]
                    flags = re.IGNORECASE if v.get("$options") == "i" else 0
                    if not re.search(pattern, str(val or ""), flags):
                        return False
            else:
                if val != v:
                    return False
        return True

    def _project(self, doc, projection):
        if not projection:
            return doc.copy()
        res = {}
        include = True
        for k, v in projection.items():
            if v == 0:
                include = False
                break
        if include:
            for k, v in projection.items():
                if v == 1:
                    res[k] = doc.get(k)
            if "_id" not in projection and "_id" in doc:
                res["_id"] = doc["_id"]
        else:
            res = doc.copy()
            for k, v in projection.items():
                if v == 0:
                    res.pop(k, None)
        return res


class MockDatabase:
    def __init__(self):
        self.users = MockCollection("users", self)
        self.buses = MockCollection("buses", self)
        self.attendance = MockCollection("attendance", self)
        self.registrations = MockCollection("registrations", self)
        self.alerts = MockCollection("alerts", self)
        self.audit_log = MockCollection("audit_log", self)
        self.live_bus_positions = MockCollection("live_bus_positions", self)
        self.live_bus_positions_history = MockCollection("live_bus_positions_history", self)
        self.sessions = MockCollection("sessions", self)
        self.emergencies = MockCollection("emergencies", self)

    def __getitem__(self, name):
        return getattr(self, name)


async def init_db():
    global mongo_client, db
    if MONGO_URI == "mock":
        logger.info("Using Mock in-memory MongoDB database client.")
        db = MockDatabase()
        users, buses, alerts, attendance = _build_seed()
        await db.users.insert_many(users)
        await db.buses.insert_many(buses)
        await db.alerts.insert_many(alerts)
        await db.attendance.insert_many(attendance)
        logger.info("Mock MongoDB database successfully initialized.")
        return

    mongo_client = AsyncIOMotorClient(MONGO_URI)
    db = mongo_client[MONGO_DB_NAME]

    # Create indexes for fast lookups
    await db.users.create_index("email", unique=True)
    await db.users.create_index("id", unique=True)
    await db.users.create_index("rfid_card", sparse=True)
    await db.buses.create_index("id", unique=True)
    await db.buses.create_index("number", unique=True)
    await db.attendance.create_index("id", unique=True)
    await db.attendance.create_index([("user_id", 1), ("date", 1)])
    await db.attendance.create_index([("bus_id", 1), ("date", 1)])
    await db.registrations.create_index("id", unique=True)
    await db.live_bus_positions.create_index("bus_id", unique=True)
    await db.alerts.create_index("id", unique=True)
    await db.emergencies.create_index("id", unique=True)
    await db.audit_log.create_index("ts")
    await db.live_bus_positions_history.create_index([("bus_id", 1), ("date", 1)])
    await db.sessions.create_index("session_id", unique=True)

    # Seed if empty
    if await db.users.count_documents({}) == 0:
        users, buses, alerts, attendance = _build_seed()
        await db.users.insert_many(users)
        await db.buses.insert_many(buses)
        await db.alerts.insert_many(alerts)
        await db.attendance.insert_many(attendance)
        logger.info("MongoDB seeded with demo data")

    logger.info("MongoDB connected — database: %s", MONGO_DB_NAME)
