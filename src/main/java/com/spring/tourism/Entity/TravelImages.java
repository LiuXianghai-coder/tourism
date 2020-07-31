package com.spring.tourism.Entity;

import java.util.List;

public class TravelImages {
    private TravelProductEntity travelProductEntity;

    private java.util.List<TravelImageEntity> travelImageEntities;

    public TravelProductEntity getTravelProductEntity() {
        return travelProductEntity;
    }

    public void setTravelProductEntity(TravelProductEntity travelProductEntity) {
        this.travelProductEntity = travelProductEntity;
    }

    public List<TravelImageEntity> getTravelImageEntities() {
        return travelImageEntities;
    }

    public void setTravelImageEntities(List<TravelImageEntity> travelImageEntities) {
        this.travelImageEntities = travelImageEntities;
    }
}
