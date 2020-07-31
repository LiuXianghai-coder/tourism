package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;
import java.util.Objects;

public class TravelStokeEntityPK implements Serializable {
    private String travelId;
    private short travelStepId;

    @Column(name = "travel_id")
    @Id
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Column(name = "travel_step_id")
    @Id
    public short getTravelStepId() {
        return travelStepId;
    }

    public void setTravelStepId(short travelStepId) {
        this.travelStepId = travelStepId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        TravelStokeEntityPK that = (TravelStokeEntityPK) o;

        if (travelStepId != that.travelStepId) return false;
        if (!Objects.equals(travelId, that.travelId)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = travelId != null ? travelId.hashCode() : 0;
        result = 31 * result + (int) travelStepId;
        return result;
    }
}
