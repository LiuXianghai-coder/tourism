package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;
import java.util.Objects;

public class TravelImageEntityPK implements Serializable {
    private String travelId;
    private String imageAddress;

    @Column(name = "travel_id")
    @Id
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Column(name = "image_address")
    @Id
    public String getImageAddress() {
        return imageAddress;
    }

    public void setImageAddress(String imageAddress) {
        this.imageAddress = imageAddress;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        TravelImageEntityPK that = (TravelImageEntityPK) o;

        if (!Objects.equals(travelId, that.travelId)) return false;
        if (!Objects.equals(imageAddress, that.imageAddress)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = travelId != null ? travelId.hashCode() : 0;
        result = 31 * result + (imageAddress != null ? imageAddress.hashCode() : 0);
        return result;
    }
}
