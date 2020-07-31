package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;
import java.util.Objects;

public class TravelKindEntityPK implements Serializable {
    private String travelId;
    private int kindId;

    @Column(name = "travel_id")
    @Id
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Column(name = "kind_id")
    @Id
    public int getKindId() {
        return kindId;
    }

    public void setKindId(int kindId) {
        this.kindId = kindId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        TravelKindEntityPK that = (TravelKindEntityPK) o;

        if (kindId != that.kindId) return false;
        if (!Objects.equals(travelId, that.travelId)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = travelId != null ? travelId.hashCode() : 0;
        result = 31 * result + kindId;
        return result;
    }
}
