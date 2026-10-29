from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class Model(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)


class Node(Model):
    id: str = Field(pattern=r"^[A-Za-z0-9_\-]+$", min_length=1, max_length=80)
    x: float
    y: float
    fixed_green: float = Field(default=30, ge=5, le=120)
    min_green: float = Field(default=10, ge=5, le=120)
    max_green: float = Field(default=40, ge=5, le=120)

    @model_validator(mode="after")
    def green_bounds(self):
        if not self.min_green <= self.fixed_green <= self.max_green:
            raise ValueError("Le vert fixe doit respecter les durées minimale et maximale.")
        return self


class Road(Model):
    id: str = Field(pattern=r"^[A-Za-z0-9_\-]+$", min_length=1, max_length=180)
    source: str
    target: str
    lanes: int = Field(default=1, ge=1, le=4)
    speed: float = Field(default=13.89, gt=0)


class Crossing(Model):
    id: str = Field(pattern=r"^[A-Za-z0-9_\-]+$", min_length=1, max_length=80)
    node: str
    roads: list[str] = Field(min_length=1, max_length=8)


class Network(Model):
    nodes: list[Node]
    roads: list[Road]
    crossings: list[Crossing] = Field(default_factory=list)
    auto_crossings: bool = True


class DemandSurge(Model):
    time: float = Field(ge=0)
    vehicles: int = Field(default=20, ge=0, le=500)
    pedestrians: int = Field(default=0, ge=0, le=500)

    @model_validator(mode="after")
    def nonempty(self):
        if self.vehicles + self.pedestrians == 0:
            raise ValueError("Ajouter au moins un véhicule ou piéton à l'événement.")
        return self


class RoadClosure(Model):
    type: Literal["closure", "accident"] = "closure"
    time: float = Field(ge=0)
    road: str
    duration: float = Field(default=30, gt=0, le=600)


class Scenario(Model):
    schema_version: Literal[1] = 1
    name: str = Field(default="Grille de démonstration", min_length=1, max_length=120)
    description: str = Field(default="", max_length=2000)
    seed: int = Field(default=42, ge=0, le=2147483647)
    duration: float = Field(default=120, gt=0)
    step_length: float = Field(default=0.1, gt=0, le=1)
    vehicles: int = Field(default=100, ge=0, le=2000)
    pedestrians: int = Field(default=30, ge=0, le=1000)
    vehicle_rate: float | None = Field(default=None, gt=0, le=50000)
    pedestrian_rate: float | None = Field(default=None, gt=0, le=50000)
    events: list[DemandSurge | RoadClosure] = Field(default_factory=list)
    controller: Literal["fixed", "adaptive"] = "fixed"
    demand_profile: Literal["steady", "peak"] = "steady"
    vehicle_origins: list[str] = Field(default_factory=list)
    vehicle_destinations: list[str] = Field(default_factory=list)
    pedestrian_origins: list[str] = Field(default_factory=list)
    pedestrian_destinations: list[str] = Field(default_factory=list)
    network: Network

    @model_validator(mode="after")
    def validate_duration(self):
        if self.duration < self.step_length:
            raise ValueError("La durée doit couvrir au moins un pas de simulation.")
        if any(event.time >= self.duration for event in self.events):
            raise ValueError("Chaque événement doit précéder la fin du scénario.")
        roads = {road.id for road in self.network.roads}
        if any(isinstance(event, RoadClosure) and event.road not in roads for event in self.events):
            raise ValueError("Un incident utilise une route inconnue.")
        for origins in (
            self.vehicle_origins,
            self.vehicle_destinations,
            self.pedestrian_origins,
            self.pedestrian_destinations,
        ):
            if set(origins) - roads:
                raise ValueError("Un point d'entrée ou de destination utilise une route inconnue.")
        return self
